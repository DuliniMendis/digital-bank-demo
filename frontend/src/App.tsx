import { useEffect, useState } from 'react'
import { getAccounts, postTransfers, resetDemo } from './lib/api'
import type { Account, Transfer } from './lib/api'
import { AccountsSection } from './components/AccountsSection'
import { PageHeader } from './components/PageHeader'
import { UploadSection } from './components/UploadSection'

// What the page is waiting for, if anything. It decides where the spinner
// shows, and stops a second click while the first is under way.
type Busy = 'loading' | 'uploading' | 'resetting' | null

// The whole page. Everything the page remembers is kept here, along with what
// the two buttons do. The components below only show what they are given.
export default function App() {
  const [accounts, setAccounts] = useState<Account[]>([])

  // The transfers from the most recent upload, or null before any upload.
  // They are only kept here, so they are gone when the page is reloaded.
  const [results, setResults] = useState<Transfer[] | null>(null)

  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState<Busy>('loading')

  // Runs once, when the page first appears.
  useEffect(() => {
    getAccounts()
      .then(setAccounts)
      .catch((caught) => showError('The accounts could not be loaded.', caught))
      .finally(() => setBusy(null))
  }, [])

  // The message starts with what the page was doing, so the person knows
  // which of the three requests failed, and ends with the reason.
  function showError(whatFailed: string, caught: unknown) {
    const reason = caught instanceof Error ? caught.message : 'Something went wrong.'
    setError(`${whatFailed} ${reason}`)
  }

  async function upload(file: File) {
    setBusy('uploading')
    setError(null)
    try {
      const result = await postTransfers(file)
      setResults(result.transfers)
      setAccounts(result.accounts)
    } catch (caught) {
      showError('The upload failed.', caught)
    } finally {
      setBusy(null)
    }
  }

  async function reset() {
    setBusy('resetting')
    setError(null)
    try {
      setAccounts(await resetDemo())
      setResults(null)
    } catch (caught) {
      showError('The reset failed.', caught)
    } finally {
      setBusy(null)
    }
  }

  return (
    <div className="page">
      <PageHeader resetting={busy === 'resetting'} disabled={busy !== null} onReset={reset} />

      {error && (
        <p role="alert" className="notice notice-error">
          {error}
        </p>
      )}

      <AccountsSection accounts={accounts} loading={busy === 'loading'} errorShown={error !== null} />
      <UploadSection
        uploading={busy === 'uploading'}
        disabled={busy !== null}
        results={results}
        onUpload={upload}
      />
    </div>
  )
}
