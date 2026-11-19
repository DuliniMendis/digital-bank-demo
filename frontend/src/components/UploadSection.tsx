import type { Transfer } from '../lib/api'
import { UploadForm } from './UploadForm'
import { UploadResult } from './UploadResult'

type Props = {
  uploading: boolean
  // The transfers from the most recent upload, or null before any upload.
  results: Transfer[] | null
  onUpload: (file: File) => void
}

export function UploadSection({ uploading, results, onUpload }: Props) {
  return (
    <section aria-labelledby="upload-heading">
      <h2 id="upload-heading">Apply a day's transfers</h2>
      <UploadForm busy={uploading} onUpload={onUpload} />
      {results && <UploadResult transfers={results} />}
    </section>
  )
}
