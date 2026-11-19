import type { Account } from '../api'
import { AccountsTable } from './AccountsTable'

type Props = {
  accounts: Account[]
  loading: boolean
  // True while the page is showing an error. The hint about loading the
  // accounts is left out then, because the error is the thing to read.
  errorShown: boolean
}

export function AccountsSection({ accounts, loading, errorShown }: Props) {
  return (
    <section aria-labelledby="accounts-heading">
      <h2 id="accounts-heading">Accounts</h2>
      {loading && <p className="empty">Loading…</p>}
      {!loading && accounts.length > 0 && <AccountsTable accounts={accounts} />}
      {/* The server never loads balances by itself, so a new database has no
          accounts until it is seeded. The reset button does that. */}
      {!loading && accounts.length === 0 && !errorShown && (
        <p className="empty">There are no accounts yet. Press "Reset to opening balances" to load them.</p>
      )}
    </section>
  )
}
