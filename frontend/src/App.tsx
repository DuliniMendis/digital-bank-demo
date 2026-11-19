import { useEffect, useState } from 'react'
import { ApiError, getAccounts, getHistory, postTransfers, resetDemo } from './api'
import type { Account, Transfer } from './api'
import { AccountsTable } from './components/AccountsTable'
import { TransfersTable } from './components/TransfersTable'
import { UploadForm } from './components/UploadForm'

// What the page is waiting for, if anything. It decides which button shows a
// "working" label, and stops a second click while the first is under way.
type Busy = 'loading' | 'uploading' | 'resetting' | null

export default function App() {
  const [accounts, setAccounts] = useState<Account[]>([])
  const [history, setHistory] = useState<Transfer[]>([])

  // The transfers from the most recent upload, or null before any upload.
  const [results, setResults] = useState<Transfer[] | null>(null)

  // A file the server refused because it was applied before. While this is
  // set, the page asks whether to apply it again.
  const [repeatedFile, setRepeatedFile] = useState<File | null>(null)

  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState<Busy>('loading')

  // Runs once, when the page first appears.
  useEffect(() => {
    Promise.all([getAccounts(), getHistory()])
      .then(([loadedAccounts, loadedHistory]) => {
        setAccounts(loadedAccounts)
        setHistory(loadedHistory)
      })
      .catch(showError)
      .finally(() => setBusy(null))
  }, [])

  function showError(caught: unknown) {
    setError(caught instanceof Error ? caught.message : 'Something went wrong.')
  }

  async function upload(file: File, applyAgain = false) {
    setBusy('uploading')
    setError(null)
    setRepeatedFile(null)
    try {
      const result = await postTransfers(file, applyAgain)
      setResults(result.transfers)
      setAccounts(result.accounts)
      setHistory(await getHistory())
    } catch (caught) {
      // 409 means the server has seen this exact file before and applied
      // nothing. That is a question for the user, not an error.
      if (caught instanceof ApiError && caught.status === 409) setRepeatedFile(file)
      else showError(caught)
    } finally {
      setBusy(null)
    }
  }

  async function reset() {
    setBusy('resetting')
    setError(null)
    try {
      setAccounts(await resetDemo())
      setHistory([])
      setResults(null)
      setRepeatedFile(null)
    } catch (caught) {
      showError(caught)
    } finally {
      setBusy(null)
    }
  }

  return (
    <div className="page">
      <header className="page-header">
        <div>
          <h1>Digital Bank Demo</h1>
          <p>Upload a day's transfers and see which ones go through. No account may go below $0.</p>
        </div>
        <button type="button" onClick={reset} disabled={busy !== null}>
          {busy === 'resetting' ? 'Resetting…' : 'Reset to opening balances'}
        </button>
      </header>

      {error && (
        <p role="alert" className="notice notice-error">
          {error}
        </p>
      )}

      <section aria-labelledby="accounts-heading">
        <h2 id="accounts-heading">Accounts</h2>
        {busy === 'loading' ? <p className="empty">Loading…</p> : <AccountsTable accounts={accounts} />}
      </section>

      <section aria-labelledby="upload-heading">
        <h2 id="upload-heading">Apply a day's transfers</h2>
        <UploadForm busy={busy === 'uploading'} onUpload={(file) => upload(file)} />

        {repeatedFile && (
          <div role="alert" className="notice notice-warning">
            <p>
              <strong>{repeatedFile.name} has already been applied.</strong> Nothing was changed. Applying it again
              will move the money a second time.
            </p>
            <div className="notice-actions">
              <button type="button" onClick={() => upload(repeatedFile, true)}>
                Apply again
              </button>
              <button type="button" className="quiet" onClick={() => setRepeatedFile(null)}>
                Cancel
              </button>
            </div>
          </div>
        )}

        {results && (
          <>
            <h3>Result of the last upload</h3>
            <p className="summary">{summary(results)}</p>
            {results.length > 0 && <TransfersTable transfers={results} />}
          </>
        )}
      </section>

      <section aria-labelledby="history-heading">
        <h2 id="history-heading">History</h2>
        {history.length === 0 ? (
          <p className="empty">{busy === 'loading' ? 'Loading…' : 'No transfers have been uploaded yet.'}</p>
        ) : (
          <TransfersTable transfers={history} showUploadTime />
        )}
      </section>
    </div>
  )
}

// For example "4 transfers: 3 completed, 1 rejected."
function summary(transfers: Transfer[]): string {
  if (transfers.length === 0) return 'The file contained no transfers.'

  const rejected = transfers.filter((transfer) => transfer.status === 'rejected').length
  const count = transfers.length === 1 ? '1 transfer' : `${transfers.length} transfers`
  return `${count}: ${transfers.length - rejected} completed, ${rejected} rejected.`
}
