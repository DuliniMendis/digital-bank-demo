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

async function request<T>(path: string, options?: RequestInit): Promise<T> {
  let response: Response
  try {
    response = await fetch(path, options)
  } catch {
    throw new Error('Could not reach the server.')
  }

  // An error from the API has a JSON body with an `error` message. An error
  // from anything in between (a proxy, for example) may not be JSON at all.
  const body = await response.json().catch(() => null)
  if (!response.ok) {
    throw new Error(body?.error ?? `The server answered with status ${response.status}.`)
  }
  return body as T
}

export async function getAccounts(): Promise<Account[]> {
  const body = await request<{ accounts: Account[] }>('/api/accounts')
  return body.accounts
}

export function postTransfers(file: File): Promise<UploadResult> {
  const form = new FormData()
  form.append('file', file)
  return request<UploadResult>('/api/transfers', { method: 'POST', body: form })
}

export async function resetDemo(): Promise<Account[]> {
  const body = await request<{ accounts: Account[] }>('/api/reset', { method: 'POST' })
  return body.accounts
}
