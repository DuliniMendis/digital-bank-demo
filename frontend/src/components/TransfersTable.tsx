import type { Transfer } from '../api'
import { formatTime } from '../format'

type Props = {
  transfers: Transfer[]
  // The history shows when each file was uploaded. The result of a single
  // upload does not need to, because every row would say the same.
  showUploadTime?: boolean
}

export function TransfersTable({ transfers, showUploadTime = false }: Props) {
  return (
    <div className="table-scroll">
      <table>
        <thead>
          <tr>
            {showUploadTime && <th scope="col">Uploaded</th>}
            <th scope="col">Line</th>
            <th scope="col">From</th>
            <th scope="col">To</th>
            <th scope="col" className="number">
              Amount
            </th>
            <th scope="col">Result</th>
          </tr>
        </thead>
        <tbody>
          {transfers.map((transfer, index) => (
            // A line number repeats from one file to the next, so the row's
            // position is what makes each key unique.
            <tr key={index}>
              {showUploadTime && (
                <td className="muted nowrap">{transfer.uploaded_at && formatTime(transfer.uploaded_at)}</td>
              )}
              <td className="muted">{transfer.line}</td>
              <td className="mono">{transfer.from}</td>
              <td className="mono">{transfer.to}</td>
              <td className="number">{transfer.amount}</td>
              <td>
                <span className={`status status-${transfer.status}`}>
                  {transfer.status === 'completed' ? 'Completed' : 'Rejected'}
                </span>
                {transfer.reason && <span className="reason">{transfer.reason}</span>}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
