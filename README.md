# Digital Bank Demo

A small banking service. It loads account balances for one company from a CSV
file, then applies a day's transfers from a second CSV file. A transfer that
would take the sending account below $0 is rejected.

This is the `extended` branch. The `main` branch is the simplest version that
answers the brief and keeps everything in memory. On this branch the accounts
are kept in a Postgres database.

## Running it

Requires Ruby 4.0 and a running Postgres.

Create an empty database and seed it with the opening balances. Both are done
once:

```bash
cd backend
bundle install
createdb bank_development
DATABASE_URL=postgres://localhost/bank_development bundle exec ruby db/seed.rb
```

This loads the sample balances. To seed from your own balances file, add
`BALANCES_FILE=path/to/balances.csv` in front of the command as well.

A bad line in the balances file stops the seeding, and the error names the
line. Nothing is stored from a file with a bad line.

Then start the server:

```bash
DATABASE_URL=postgres://localhost/bank_development bundle exec rackup
```

It listens on `http://localhost:9292`. The server never loads balances itself,
so it shows no accounts until the database has been seeded.

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

Balances are kept in the database, so they are still there after the server
restarts. To go back to the opening balances, run the seed command again. It
replaces whatever accounts the database holds.

## Running the tests

Most specs are tagged `:database` and need a running Postgres with an empty
database called `bank_test`. They create the tables themselves and undo their
own changes.

```bash
cd backend
createdb bank_test      # once
bundle exec rspec
bundle exec rubocop
```

To use a test database somewhere else, set `DATABASE_URL`, for example
`postgres://user:password@localhost/bank_test`. The specs for the domain and
for reading CSV files need no database. To run only those:

```bash
bundle exec rspec --tag '~database'
```

## Architecture

The code is in `backend/lib/bank/` and follows Domain-Driven Design. It has
four layers, and each one only depends on the ones above it in this table.

| Layer             | What it does                                                                |
|-------------------|-----------------------------------------------------------------------------|
| `domain/`         | The business rules: `Money`, `AccountNumber`, `Account` and `Transfer`.     |
| `use_cases/`      | The operations the app performs, built from the domain objects.             |
| `infrastructure/` | Reads the CSV files, and stores the accounts in Postgres.                   |
| `web/`            | The HTTP API. It calls the use cases and returns JSON.                      |

The domain layer is plain Ruby with no knowledge of files, the database or
HTTP, so the rules can be read and tested on their own.

There are two use cases:

| Use case           | What it does                                                            |
|--------------------|-------------------------------------------------------------------------|
| `SeedAccounts`     | Replaces the stored accounts with one for each line of the balances file. Used to seed and to reseed. |
| `ProcessTransfers` | Applies a list of transfers in order, completing or rejecting each one. |

A posted transfers file goes through the layers like this:

1. `Web::Api` reads the upload and passes the text to `Infrastructure::CsvFiles`,
   which splits it into rows.
2. `UseCases::ProcessTransfers` builds a `Transfer` from each row, finds the two
   accounts and asks the transfer to apply itself.
3. `Web::Api` returns each result, and the balances, as JSON.

### Storage

The use cases never talk to the database directly. They are handed a
*repository*, `PostgresAccountRepository`, which adds, finds and saves
accounts in the `accounts` table:

| Column          | Meaning                                                      |
|-----------------|--------------------------------------------------------------|
| `id`            | Records the order the accounts were added in.                |
| `number`        | The 16 digit account number. Must be unique.                 |
| `balance_cents` | The balance in whole cents. The database refuses a negative. |

The table is created by the file in `backend/db/migrations/`, which the server
and the seed command both run when they start.

### Decisions that shape the code

- **Money is whole cents.** Floats cannot represent every cent exactly, so
  amounts are integers and `"25.60"` is parsed straight to `2560`.
- **Each rule lives in one place.** Only `Account` knows a balance cannot go
  below $0. Only `AccountNumber` knows a number is 16 digits.
- **A broken rule raises a `Domain::Error`.** `ProcessTransfers` rescues that
  one family and records a rejection, then carries on with the next transfer.
- **A bad balances file stops everything; a bad transfer does not.** The
  starting balances have to be trustworthy. A bad transfer line is one
  rejected transfer.
- **A transfer is all or nothing.** Each one runs in its own database
  transaction, so both balances are saved or neither is. Seeding works the
  same way for the whole balances file.
- **Two transfers cannot both spend the same balance.** Looking up an account
  for a transfer locks its row in the database until that transfer is saved.
