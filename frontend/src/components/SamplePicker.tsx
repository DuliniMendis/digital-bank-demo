import { useState } from 'react'
import type { FormEvent } from 'react'
import { sampleUrl } from '../lib/api'
import { sampleLabel } from '../lib/format'
import { Spinner } from './Spinner'

type Props = {
  // The names of the sample files, as the API lists them. Never empty.
  samples: string[]
  applying: boolean
  disabled: boolean
  onApply: (name: string) => void
}

export function SamplePicker({ samples, applying, disabled, onApply }: Props) {
  const [chosen, setChosen] = useState(samples[0])

  function submit(event: FormEvent) {
    // Stops the browser from sending the form itself and reloading the page.
    event.preventDefault()
    onApply(chosen)
  }

  return (
    <form className="upload" onSubmit={submit}>
      <label htmlFor="sample-file">Or try a sample file</label>
      <div className="upload-row">
        <select id="sample-file" value={chosen} onChange={(event) => setChosen(event.target.value)}>
          {samples.map((name) => (
            <option key={name} value={name}>
              {sampleLabel(name)}
            </option>
          ))}
        </select>
        <button type="submit" disabled={disabled}>
          {applying && <Spinner />}
          {applying ? 'Applying…' : 'Apply sample'}
        </button>
      </div>
      <p className="hint">
        Each name says what to expect, counted from the opening balances. To see what is in the chosen file,{' '}
        <a href={sampleUrl(chosen)} download>
          download it
        </a>
        .
      </p>
    </form>
  )
}
