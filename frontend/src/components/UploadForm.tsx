import { useState } from 'react'
import type { FormEvent } from 'react'
import { Spinner } from './Spinner'

type Props = {
  uploading: boolean
  disabled: boolean
  onUpload: (file: File) => void
}

export function UploadForm({ uploading, disabled, onUpload }: Props) {
  const [file, setFile] = useState<File | null>(null)

  function submit(event: FormEvent) {
    // Stops the browser from sending the form itself and reloading the page.
    event.preventDefault()
    if (file) onUpload(file)
  }

  return (
    <form className="upload" onSubmit={submit}>
      <label htmlFor="transfers-file">Transfers CSV file</label>
      <div className="upload-row">
        <input
          id="transfers-file"
          type="file"
          accept=".csv,text/csv"
          onChange={(event) => setFile(event.target.files?.[0] ?? null)}
        />
        <button type="submit" className="primary" disabled={!file || disabled}>
          {uploading && <Spinner />}
          {uploading ? 'Applying…' : 'Apply transfers'}
        </button>
      </div>
      <p className="hint">
        One transfer per line, with no header row: <code>from,to,amount</code>.
      </p>
    </form>
  )
}
