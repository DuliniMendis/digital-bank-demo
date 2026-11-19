import type { Transfer } from '../api'
import { TransfersTable } from './TransfersTable'

export function UploadResult({ transfers }: { transfers: Transfer[] }) {
  return (
    <>
      <h3>Result of the last upload</h3>
      <p className="summary">{summary(transfers)}</p>
      {transfers.length > 0 && <TransfersTable transfers={transfers} />}
    </>
  )
}

// For example "4 transfers: 3 completed, 1 rejected."
function summary(transfers: Transfer[]): string {
  if (transfers.length === 0) return 'The file contained no transfers.'

  const rejected = transfers.filter((transfer) => transfer.status === 'rejected').length
  const count = transfers.length === 1 ? '1 transfer' : `${transfers.length} transfers`
  return `${count}: ${transfers.length - rejected} completed, ${rejected} rejected.`
}
