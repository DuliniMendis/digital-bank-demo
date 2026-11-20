import type { Transfer } from '../lib/api'
import { UploadForm } from './UploadForm'
import { UploadResult } from './UploadResult'

type Props = {
  uploading: boolean
  // True while the page is waiting for anything, so a file cannot be sent in
  // the middle of a reset.
  disabled: boolean
  // The transfers from the most recent upload, or null before any upload.
  results: Transfer[] | null
  onUpload: (file: File) => void
}

export function UploadSection({ uploading, disabled, results, onUpload }: Props) {
  return (
    <section aria-labelledby="upload-heading">
      <h2 id="upload-heading">Apply a day's transfers</h2>
      <UploadForm uploading={uploading} disabled={disabled} onUpload={onUpload} />
      {results && <UploadResult transfers={results} />}
    </section>
  )
}
