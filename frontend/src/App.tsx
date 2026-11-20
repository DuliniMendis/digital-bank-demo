import { useEffect, useState } from 'react'
import { getAccounts, getSampleFile, getSamples, postTransfers, resetDemo } from './lib/api'
import type { Account, Transfer } from './lib/api'
import { AccountsSection } from './components/AccountsSection'
import { PageHeader } from './components/PageHeader'
import { UploadSection } from './components/UploadSection'

// What the page is waiting for, if anything. It decides where the spinner
// shows, and stops a second click while the first is under way.
type Busy = 'loading' | 'uploading' | 'applying-sample' | 'resetting' | null

// The whole page. Everything the page remembers is kept here, along with what
// the buttons do. The components below only show what they are given.
export default function App() {
  const [accounts, setAccounts] = useState<Account[]>([])

  // The names of the sample files the API offers.
  const [samples, setSamples] = useState<string[]>([])

  // Whether the tick box is ticked. It applies to the next file sent,
  // whether that is one from the computer or a sample.
  const [settleAtEnd, setSettleAtEnd] = useState(false)

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

    // The samples are an extra. If they cannot be listed the picker is left
    // out, and the accounts request above reports what is wrong.
    getSamples()
      .then(setSamples)
      .catch(() => setSamples([]))
  }, [])

  // The message starts with what the page was doing, so the person knows
  // which request failed, and ends with the reason.
  function showError(whatFailed: string, caught: unknown) {
    const reason = caught instanceof Error ? caught.message : 'Something went wrong.'
    setError(`${whatFailed} ${reason}`)
  }

  // Sends a transfers file and shows the result. `busyAs` says which button
  // was pressed, so the spinner shows on that one. `getFile` is a function
  // because a sample has to be fetched first, and that can fail too.
  async function apply(busyAs: 'uploading' | 'applying-sample', getFile: () => Promise<File>) {
    setBusy(busyAs)
    setError(null)
    try {
      const result = await postTransfers(await getFile(), settleAtEnd)
      setResults(result.transfers)
      setAccounts(result.accounts)
    } catch (caught) {
      showError('The upload failed.', caught)
    } finally {
      setBusy(null)
    }
  }

  function upload(file: File) {
    return apply('uploading', async () => file)
  }

  // A sample goes through the same upload as a file picked from the
  // computer, so the API treats the two in exactly the same way.
  function applySample(name: string) {
    return apply('applying-sample', () => getSampleFile(name))
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
        applyingSample={busy === 'applying-sample'}
        disabled={busy !== null}
        results={results}
        samples={samples}
        settleAtEnd={settleAtEnd}
        onSettleAtEndChange={setSettleAtEnd}
        onUpload={upload}
        onApplySample={applySample}
      />
    </div>
  )
}
