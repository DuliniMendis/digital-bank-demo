# Digital Bank Demo

This is a small banking service that uses Ruby. It loads account balances for one company from a CSV
file, then applies a day's transfers from a second CSV file. A transfer that
would take the sending account below $0 is rejected.

**A hosted version is at <https://digital-bank-demo-flame.vercel.app>.** It
runs the `extended` branch, which adds a web page and a database to what is
described here.

## Running it

Requires Ruby 3.3 or newer.

Start the server:

```bash
bundle install
bundle exec rackup
```

This loads the sample balances into memory and listens on
`http://localhost:9292`. To start from your own balances file, name it:

```bash
BALANCES_FILE=path/to/balances.csv bundle exec rackup
```

A bad line in the balances file stops the server from starting, and an error
with the line number would indicate what the issue was.

From a second terminal, post a day's transfers:

```bash
curl -F file=@spec/fixtures/transfers.csv http://localhost:9292/transfers
```

The response lists each transfer as `completed` or `rejected`, with the line
number and the reason for a rejection, followed by the balances afterwards.

By default each transfer has to be affordable at the moment it is applied. To
check the balances only once, after the whole file, add `settle_at_end`:

```bash
curl -F file=@spec/fixtures/transfers.csv -F settle_at_end=true http://localhost:9292/transfers
```

A transfer may then spend money that arrives later in the file. If the file
would leave any account below $0, nothing in it is applied, and every transfer
in it is rejected with that reason.

To see the balances at any time:

```bash
curl http://localhost:9292/accounts
```

A header row is optional in both CSV files. A row in the CSV for balances includes
`account number,balance` and a row in the CSV for transfers includes `from,to,amount`. Sample
files are in `spec/fixtures/`.

Balances are only reset when the server restarts.

Nothing stops the same transfers file being posted twice, and that is on
purpose. A second post is applied as a second set of transfers, because two
files with the same lines can both be genuine.

## Running the tests

Run `bundle install` first if you have not started the server yet.

```bash
bundle exec rspec       # the specs
bundle exec rubocop     # the linter
```

To run the specs in one file, name it:

```bash
bundle exec rspec spec/bank/domain/money_spec.rb
```

## Architecture

The code is in `lib/bank/` and follows Domain-Driven Design. It has
four layers, and each one only depends on the ones above it in this table.

| Layer             | What it does                                                                |
|-------------------|-----------------------------------------------------------------------------|
| `domain/`         | The business rules: `Money`, `AccountNumber`, `Account` and `Transfer`.     |
| `application/`    | `LoadAccounts` and `ProcessTransfers`, which put the domain objects to work.|
| `infrastructure/` | Reads the CSV files, and keeps the accounts in memory.                      |
| `interfaces/`     | The HTTP API. It calls the application services and returns JSON.           |

The domain layer is plain Ruby with no knowledge of files or HTTP, so the
rules can be read and tested on their own.

A posted transfers file goes through the layers like this:

1. `Interfaces::Api` reads the upload and passes the text to `Infrastructure::CsvFiles`,
   which splits it into rows.
2. `Application::ProcessTransfers` builds a `Transfer` from each row, finds the two
   accounts and asks the transfer to apply itself.
3. `Interfaces::Api` returns each result, and the balances, as JSON.

A few decisions shape the code:

- **Money is whole cents.** Since dealing with integers is safer and
  unambiguous for monetary values, the amounts are represented as cents
  and `"25.60"` is parsed straight to `2560`.
- **Each rule lives with the relevant domain object.** Only `Account` knows
  a balance cannot go below $0. Only `AccountNumber` knows a number is 16 digits.
- **A broken rule raises a `Domain::Error`.** `ProcessTransfers` records a
  rejection for an erroneous transfer, then carries on with the next transfer.
- **A bad balances file stops everything; a bad transfer does not.** The
  starting balances have to be trustworthy, so loading the entire balances
  file is aborted if one of the balances is wrong. A bad transfer line is one
  rejected transfer, so the other transfer rows are still processed.
- **Transfers are applied one at a time, in the order of the file.** Each
  transfer sees the balances left by the ones before it. An early transfer
  can complete and a later one from the same account be rejected, because
  the money has already gone. In the same way, money that arrives early in
  the file can be spent later in it. Putting the lines in a different order
  can therefore change which ones are rejected. The edge-case fixture
  `3_completed_3_rejected_overdraft_limit.csv` shows both cases.
- **Settling at the end is an option, and it is all or nothing.** With
  `settle_at_end`, each account first receives everything coming to it in the
  file and then pays out everything leaving it, so the order of the lines no
  longer matters. Every account is checked before any balance changes. A line
  that cannot be read, or that names an unknown account, is still rejected by
  itself. `Account` owns this rule too, next to the one for a single
  withdrawal.

## Extensions

This branch is the simplest version that answers the brief. The `extended`
branch builds on it with the things a real service would need:

- **A web page**, built with React, for uploading a file and seeing the
  balances and the result of that upload.
- **A live deployment**, hosted on Vercel.
- **A Postgres database.** Balances survive a restart and are seeded in a DB.
  Uses a Neon DB through Vercel.
- **Locking, so uploads that arrive together are safe.** Each transfer runs
  in a database transaction that can rollback if either the withdrawal
  or deposit fails.
- **React component tests and E2E tests**, built with React Testing Library,
  Vitest and Playwright.

Locking was left out of this branch on purpose. The server here can handle
two requests at once, so two uploads arriving at the same moment could both
spend the same balance. A database solves that properly with transactions and
row locks.

### Running the extended branch

**The extended branch is hosted at <https://digital-bank-demo-flame.vercel.app>.
Use that to test it without installing anything.**

To run it yourself instead, it requires Node 26 and a running Postgres as well as Ruby. On that branch the
Ruby code is in `backend/` and the web page is in `frontend/`.

Switch to the branch, then create a database and seed it with the sample
balances. Creating and seeding are done once:

```bash
git switch extended
cd backend
bundle install
createdb bank_development
DATABASE_URL=postgres://localhost/bank_development bundle exec ruby db/seed.rb
```

Start the API, which listens on `http://localhost:9292`:

```bash
DATABASE_URL=postgres://localhost/bank_development bundle exec rackup
```

Start the web page from a second terminal, then open `http://localhost:5173`:

```bash
cd frontend
npm install
npm run dev
```

The Ruby specs and the linter need an empty database called `bank_test`:

```bash
cd backend
createdb bank_test      # once
bundle exec rspec
bundle exec rubocop
```

The web page has its own tests and linter, which need neither the API nor a
database:

```bash
cd frontend
npm test
npm run lint
```

The end-to-end tests open the page in a real browser against the real API and
a database of their own. They start the API and the page themselves, so
nothing else needs to be running:

```bash
cd frontend
createdb bank_e2e                     # once
npx playwright install chromium       # once: downloads the browser
npm run e2e
```

The README on the `extended` branch explains each of these in more detail.
