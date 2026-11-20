// Everything the page asks of the Ruby API. No other file calls `fetch`.

export type Account = {
  number: string
  // A string such as "4820.50". The API never sends money as a number,
  // because a JavaScript number is a float, and any sums done with it could
  // drift by a fraction of a cent.
  balance: string
}

export type Transfer = {
  line: number
  // These three are the text of the uploaded line, so a rejected line can
  // hold anything, or nothing.
  from: string | null
  to: string | null
  amount: string | null
  status: 'completed' | 'rejected'
  reason: string | null
}

export type UploadResult = {
  transfers: Transfer[]
  accounts: Account[]
}

// `fetch` only fails when no answer arrives at all. An answer that reports an
// error, such as a 404, still counts as an answer and is returned.
async function send(path: string, options?: RequestInit): Promise<Response> {
  try {
    return await fetch(path, options)
  } catch {
    throw new Error('The server could not be reached. Check your connection, then try again.')
  }
}

async function request<T>(path: string, options?: RequestInit): Promise<T> {
  const response = await send(path, options)

  // An error from the API has a JSON body with an `error` message. An error
  // from anything in between (a proxy, for example) may not be JSON at all.
  const body = await response.json().catch(() => null)
  if (!response.ok) {
    throw new Error(body?.error ?? `The server answered with status ${response.status}. Try again in a moment.`)
  }
  return body as T
}

export async function getAccounts(): Promise<Account[]> {
  const body = await request<{ accounts: Account[] }>('/api/accounts')
  return body.accounts
}

// With `settleAtEnd` the API checks the balances once, after the whole file,
// and not after every line.
export function postTransfers(file: File, settleAtEnd: boolean): Promise<UploadResult> {
  const form = new FormData()
  form.append('file', file)
  if (settleAtEnd) form.append('settle_at_end', 'true')
  return request<UploadResult>('/api/transfers', { method: 'POST', body: form })
}

// The names of the sample transfers files the API offers.
export async function getSamples(): Promise<string[]> {
  const body = await request<{ samples: string[] }>('/api/samples')
  return body.samples
}

// Where one sample file can be downloaded from.
export function sampleUrl(name: string): string {
  return `/api/samples/${encodeURIComponent(name)}`
}

// Fetches one sample file as a File, so it can be sent through the same
// upload as a file picked from the computer.
export async function getSampleFile(name: string): Promise<File> {
  const response = await send(sampleUrl(name))
  if (!response.ok) {
    throw new Error(`The sample file could not be fetched (status ${response.status}).`)
  }
  return new File([await response.blob()], name, { type: 'text/csv' })
}

export async function resetDemo(): Promise<Account[]> {
  const body = await request<{ accounts: Account[] }>('/api/reset', { method: 'POST' })
  return body.accounts
}
