// Everything the page asks of the Ruby API. No other file calls `fetch`.

export type Account = {
  number: string
  // A string such as "4820.50". The API never sends money as a number,
  // because JavaScript numbers are floats and can be a cent out.
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
  // Only present on transfers read from the history.
  uploaded_at?: string
}

export type UploadResult = {
  transfers: Transfer[]
  accounts: Account[]
}

// Thrown when the API answers with an error. `status` is the HTTP status,
// which the page uses to tell "already applied" (409) from other failures.
export class ApiError extends Error {
  status: number

  constructor(message: string, status: number) {
    super(message)
    this.status = status
  }
}

async function request<T>(path: string, options?: RequestInit): Promise<T> {
  let response: Response
  try {
    response = await fetch(path, options)
  } catch {
    throw new ApiError('Could not reach the server.', 0)
  }

  // An error from the API has a JSON body with an `error` message. An error
  // from anything in between (a proxy, for example) may not be JSON at all.
  const body = await response.json().catch(() => null)
  if (!response.ok) {
    throw new ApiError(body?.error ?? `The server answered with status ${response.status}.`, response.status)
  }
  return body as T
}

export async function getAccounts(): Promise<Account[]> {
  const body = await request<{ accounts: Account[] }>('/api/accounts')
  return body.accounts
}

export async function getHistory(): Promise<Transfer[]> {
  const body = await request<{ transfers: Transfer[] }>('/api/transfers')
  return body.transfers
}

// `applyAgain` confirms that a file the server has seen before should be
// applied a second time.
export function postTransfers(file: File, applyAgain = false): Promise<UploadResult> {
  const form = new FormData()
  form.append('file', file)
  if (applyAgain) form.append('apply_again', 'true')
  return request<UploadResult>('/api/transfers', { method: 'POST', body: form })
}

export async function resetDemo(): Promise<Account[]> {
  const body = await request<{ accounts: Account[] }>('/api/reset', { method: 'POST' })
  return body.accounts
}
