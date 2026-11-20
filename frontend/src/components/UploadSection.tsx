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
  settleAtEnd: boolean
  onSettleAtEndChange: (ticked: boolean) => void
  onUpload: (file: File) => void
  onApplySample: (name: string) => void
}

export function UploadSection(props: Props) {
  const { uploading, applyingSample, disabled, results, samples, onUpload, onApplySample } = props
  const { settleAtEnd, onSettleAtEndChange } = props

  return (
    <section aria-labelledby="upload-heading">
      <h2 id="upload-heading">Apply a day's transfers</h2>
      <label className="option">
        <input
          type="checkbox"
          checked={settleAtEnd}
          disabled={disabled}
          onChange={(event) => onSettleAtEndChange(event.target.checked)}
        />
        Check balances only at the end of the file
      </label>
      <p className="hint">
        Ticked, a transfer may spend money that arrives later in the file, and a file that would leave any account below
        $0 is refused as a whole.
      </p>
      <UploadForm uploading={uploading} disabled={disabled} onUpload={onUpload} />
      {samples.length > 0 && (
        <SamplePicker samples={samples} applying={applyingSample} disabled={disabled} onApply={onApplySample} />
      )}
      {results && <UploadResult transfers={results} />}
    </section>
  )
}
