import { render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, expect, test, vi } from 'vitest'
import App from './App'
import type { Account, Transfer } from './lib/api'

// These tests render the whole page and replace `fetch` with a stand-in, so
// no server is needed. Each test says what the "server" will answer, then
// uses the page the way a person would.

const openingAccounts: Account[] = [
  { number: '1111234522226789', balance: '5000.00' },
  { number: '1212343433335665', balance: '1200.00' },
]

const completed: Transfer = {
  line: 1,
  from: '1111234522226789',
  to: '1212343433335665',
  amount: '500.00',
  status: 'completed',
  reason: null,
}

const rejected: Transfer = {
  line: 2,
  from: '1111234522226789',
  to: '1212343433335665',
  amount: '9999.00',
  status: 'rejected',
  reason: 'account 1111234522226789 does not have sufficient funds to withdraw $9999.00',
}

const afterTransfer: Account[] = [
  { number: '1111234522226789', balance: '4500.00' },
  { number: '1212343433335665', balance: '1700.00' },
]

// One answer from the stand-in server: an HTTP status and a JSON body.
type Answer = { status: number; body: unknown }

// What the stand-in answers to each kind of request. A test changes an entry
// to set up its scenario.
let server: {
  accounts: Answer
  upload: Answer
  reset: Answer
}

// Every upload the page sent, so a test can check what was in the form.
let uploadsSent: FormData[]

function fakeFetch(path: string | URL | Request, options?: RequestInit): Promise<Response> {
  const method = options?.method ?? 'GET'
  let answer: Answer

  if (method === 'POST' && path === '/api/transfers') {
    uploadsSent.push(options?.body as FormData)
    answer = server.upload
  } else if (method === 'POST' && path === '/api/reset') {
    answer = server.reset
  } else {
    answer = server.accounts
  }

  return Promise.resolve(new Response(JSON.stringify(answer.body), { status: answer.status }))
}

beforeEach(() => {
  server = {
    accounts: { status: 200, body: { accounts: openingAccounts } },
    upload: { status: 200, body: { transfers: [], accounts: openingAccounts } },
    reset: { status: 200, body: { accounts: openingAccounts } },
  }
  uploadsSent = []
  vi.stubGlobal('fetch', vi.fn(fakeFetch))
})

afterEach(() => {
  vi.unstubAllGlobals()
})

// Picks a file in the file input and presses the button, as a person would.
async function uploadFile(name = 'transfers.csv') {
  const user = userEvent.setup()
  const file = new File(['1111234522226789,1212343433335665,500.00\n'], name, { type: 'text/csv' })
  await user.upload(screen.getByLabelText('Transfers CSV file'), file)
  await user.click(screen.getByRole('button', { name: 'Apply transfers' }))
  return user
}

function section(name: string) {
  return within(screen.getByRole('region', { name }))
}

test('shows the balances when the page opens', async () => {
  render(<App />)

  expect(await screen.findByText('$5,000.00')).toBeInTheDocument()
})

test('uploading a file shows each transfer and the new balances', async () => {
  server.upload = { status: 200, body: { transfers: [completed], accounts: afterTransfer } }
  render(<App />)
  await screen.findByText('$5,000.00')

  await uploadFile()

  expect(await screen.findByText('1 transfer: 1 completed, 0 rejected.')).toBeInTheDocument()
  expect(section('Accounts').getByText('$4,500.00')).toBeInTheDocument()
  expect(screen.getByText('Completed')).toBeInTheDocument()
  expect((uploadsSent[0].get('file') as File).name).toBe('transfers.csv')
})

test('a rejected transfer is shown with the reason', async () => {
  server.upload = { status: 200, body: { transfers: [completed, rejected], accounts: afterTransfer } }
  render(<App />)
  await screen.findByText('$5,000.00')

  await uploadFile()

  expect(await screen.findByText('2 transfers: 1 completed, 1 rejected.')).toBeInTheDocument()
  expect(screen.getByText('Rejected')).toBeInTheDocument()
  expect(screen.getByText(/does not have sufficient funds to withdraw \$9999.00/)).toBeInTheDocument()
})

test('an error from the server is shown', async () => {
  server.upload = { status: 400, body: { error: 'The file is not valid CSV: unclosed quote' } }
  render(<App />)
  await screen.findByText('$5,000.00')

  await uploadFile()

  expect(await screen.findByRole('alert')).toHaveTextContent('The file is not valid CSV: unclosed quote')
})

test('a database with no accounts says how to load them', async () => {
  server.accounts = { status: 200, body: { accounts: [] } }
  render(<App />)

  expect(await screen.findByText(/There are no accounts yet/)).toBeInTheDocument()

  await userEvent.setup().click(screen.getByRole('button', { name: 'Reset to opening balances' }))

  expect(await section('Accounts').findByText('$5,000.00')).toBeInTheDocument()
})

test('reset puts the opening balances back and clears the result', async () => {
  server.upload = { status: 200, body: { transfers: [completed], accounts: afterTransfer } }
  render(<App />)
  await screen.findByText('$5,000.00')
  const user = await uploadFile()
  await section('Accounts').findByText('$4,500.00')

  await user.click(screen.getByRole('button', { name: 'Reset to opening balances' }))

  expect(await section('Accounts').findByText('$5,000.00')).toBeInTheDocument()
  expect(screen.queryByText('Result of the last upload')).not.toBeInTheDocument()
})
