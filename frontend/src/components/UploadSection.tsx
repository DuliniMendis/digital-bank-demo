import type { Transfer } from '../lib/api'
import { SamplePicker } from './SamplePicker'
import { UploadForm } from './UploadForm'
import { UploadResult } from './UploadResult'

type Props = {
  uploading: boolean
  applyingSample: boolean
  // True while the page is waiting for anything, so a file cannot be sent in
  // the middle of a reset.
  disabled: boolean
  // The transfers from the most recent upload, or null before any upload.
  results: Transfer[] | null
  // The names of the sample files. Empty until the API has listed them.
  samples: string[]
  onUpload: (file: File) => void
  onApplySample: (name: string) => void
}

export function UploadSection(props: Props) {
  const { uploading, applyingSample, disabled, results, samples, onUpload, onApplySample } = props

  return (
    <section aria-labelledby="upload-heading">
      <h2 id="upload-heading">Apply a day's transfers</h2>
      <UploadForm uploading={uploading} disabled={disabled} onUpload={onUpload} />
      {samples.length > 0 && (
        <SamplePicker samples={samples} applying={applyingSample} disabled={disabled} onApply={onApplySample} />
      )}
      {results && <UploadResult transfers={results} />}
    </section>
  )
}
