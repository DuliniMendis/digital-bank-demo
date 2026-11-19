# Digital Bank Demo

A small banking service. It loads account balances for one company from a CSV
file, then applies a day's transfers from a second CSV file. A transfer that
would take the sending account below $0 is rejected.

## Running it

Requires Ruby 3.3 or newer.

Start the server with a balances file:

```bash
cd backend
bundle install
BALANCES_FILE=spec/fixtures/account_balances.csv bundle exec rackup
```

The balances are loaded into memory and the server listens on
`http://localhost:9292`. A bad line in the balances file stops the server from
starting, and the error names the line.

From a second terminal, in `backend/`, post a day's transfers:

```bash
curl -F file=@spec/fixtures/transfers.csv http://localhost:9292/transfers
```

The response lists each transfer as `completed` or `rejected`, with the line
number and the reason for a rejection, followed by the balances afterwards.

To see the balances at any time:

```bash
curl http://localhost:9292/accounts
```

A header row is optional in both CSV files. A balances line is
`account number,balance` and a transfers line is `from,to,amount`. Sample
files are in `backend/spec/fixtures/`.

Balances carry over from one post to the next, and reset when the server
restarts.

## Running the tests

```bash
cd backend
bundle exec rspec
bundle exec rubocop
```

## Architecture

The code is in `backend/lib/bank/` and follows Domain-Driven Design. It has
four layers, and each one only depends on the ones above it in this table.

| Layer             | What it does                                                                |
|-------------------|-----------------------------------------------------------------------------|
| `domain/`         | The business rules: `Money`, `AccountNumber`, `Account` and `Transfer`.     |
| `use_cases/`      | `LoadAccounts` and `ProcessTransfers`, which put the domain objects to work.|
| `infrastructure/` | Reads the CSV files, and keeps the accounts in memory.                      |
| `web/`            | The HTTP API. It calls the use cases and returns JSON.                      |

The domain layer is plain Ruby with no knowledge of files or HTTP, so the
rules can be read and tested on their own.

A posted transfers file goes through the layers like this:

1. `Web::Api` reads the upload and passes the text to `Infrastructure::CsvFiles`,
   which splits it into rows.
2. `UseCases::ProcessTransfers` builds a `Transfer` from each row, finds the two
   accounts and asks the transfer to apply itself.
3. `Web::Api` returns each result, and the balances, as JSON.

A few decisions shape the code:

- **Money is whole cents.** Floats cannot represent every cent exactly, so
  amounts are integers and `"25.60"` is parsed straight to `2560`.
- **Each rule lives in one place.** Only `Account` knows a balance cannot go
  below $0. Only `AccountNumber` knows a number is 16 digits.
- **A broken rule raises a `Domain::Error`.** `ProcessTransfers` rescues that
  one family and records a rejection, then carries on with the next transfer.
- **A bad balances file stops everything; a bad transfer does not.** The
  starting balances have to be trustworthy. A bad transfer line is one
  rejected transfer.
- **One transfers file is processed at a time**, so two uploads cannot both
  spend the same balance.
