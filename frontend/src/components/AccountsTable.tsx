import type { Account } from '../api'
import { formatMoney } from '../format'

export function AccountsTable({ accounts }: { accounts: Account[] }) {
  return (
    <div className="table-scroll">
      <table>
        <thead>
          <tr>
            <th scope="col">Account number</th>
            <th scope="col" className="number">
              Balance
            </th>
          </tr>
        </thead>
        <tbody>
          {accounts.map((account) => (
            <tr key={account.number}>
              <td className="mono">{account.number}</td>
              <td className="number">{formatMoney(account.balance)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
