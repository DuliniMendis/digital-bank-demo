type Props = {
  resetting: boolean
  // True while the page is waiting for anything, so the button cannot be
  // pressed in the middle of an upload.
  disabled: boolean
  onReset: () => void
}

export function PageHeader({ resetting, disabled, onReset }: Props) {
  return (
    <header className="page-header">
      <div>
        <h1>Digital Bank Demo</h1>
        <p>Upload a day's transfers and see which ones go through. No account may go below $0.</p>
      </div>
      <button type="button" onClick={onReset} disabled={disabled}>
        {resetting ? 'Resetting…' : 'Reset to opening balances'}
      </button>
    </header>
  )
}
