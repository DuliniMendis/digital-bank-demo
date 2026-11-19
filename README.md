# Digital Bank Demo

This is small banking service that uses Ruby. It loads account balances for one company from a CSV
file, then applies a day's transfers from a second CSV file. A transfer that
would take the sending account below $0 is rejected.

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

To see the balances at any time:

```bash
curl http://localhost:9292/accounts
```

A header row is optional in both CSV files. A row in the CSV for balances include
`account number,balance` and a a row in the CSV for transfers include `from,to,amount`. Sample
files are in `spec/fixtures/`.

Balances are only reset when the server restarts.

## Running the tests

```bash
bundle exec rspec
bundle exec rubocop
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
  
## Extensions

This branch is the simplest version that answers the brief. The `extended`
branch builds on it with the things a real service would need:

- **A web page**, built with React, for uploading a file and seeing the
  balances and the history.
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
