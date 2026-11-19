import type { Transfer } from '../api'
import { TransfersTable } from './TransfersTable'

type Props = {
  history: Transfer[]
  loading: boolean
}

export function HistorySection({ history, loading }: Props) {
  return (
    <section aria-labelledby="history-heading">
      <h2 id="history-heading">History</h2>
      {history.length === 0 ? (
        <p className="empty">{loading ? 'Loading…' : 'No transfers have been uploaded yet.'}</p>
      ) : (
        <TransfersTable transfers={history} showUploadTime />
      )}
    </section>
  )
}
