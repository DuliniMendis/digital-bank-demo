import type { Transfer } from '../lib/api'

export function TransfersTable({ transfers }: { transfers: Transfer[] }) {
  return (
    <div className="table-scroll">
      <table>
        <thead>
          <tr>
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
          {transfers.map((transfer) => (
            <tr key={transfer.line}>
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
