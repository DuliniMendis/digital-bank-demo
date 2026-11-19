# Digital Bank Demo

A small banking service. It loads account balances for one company from a CSV
file, then applies a day's transfers from a second CSV file. A transfer that
would take the sending account below $0 is rejected.

This is the `extended` branch. The `main` branch is the simplest version that
answers the brief and keeps everything in memory. This branch adds a Postgres
database, a history of every transfer, protection against applying the same
file twice, and a web page to use it from.

```
backend/    Ruby: the business rules, the database and the HTTP API
frontend/   React: the web page
```

## Running it

Requires Ruby 4.0, Node 26 and a running Postgres.

### The API

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

It listens on `http://localhost:9292`. The server never loads balances when it
starts, so it shows no accounts until the database has been seeded.

From a second terminal, in `backend/`, post a day's transfers:

```bash
curl -F file=@spec/fixtures/transfers.csv http://localhost:9292/api/transfers
```

The response lists each transfer as `completed` or `rejected`, with the line
number and the reason for a rejection, followed by the balances afterwards.

Posting the same file a second time is refused with a 409, because it would
pay everyone twice. To apply it again on purpose:

```bash
curl -F file=@spec/fixtures/transfers.csv -F apply_again=true http://localhost:9292/api/transfers
```

The other routes:

```bash
curl http://localhost:9292/api/accounts           # the current balances
curl http://localhost:9292/api/transfers          # every transfer so far, newest file first
curl -X POST http://localhost:9292/api/reset      # reseeds: opening balances again, no history
```

A header row is optional in both CSV files. A balances line is
`account number,balance` and a transfers line is `from,to,amount`. Sample
files are in `backend/spec/fixtures/`.

Balances and history are kept in the database, so they are still there after
the server restarts. To go back to the opening balances, reseed: either post
to the reset route or run the seed command again. Both replace the accounts
and empty the history. The reset route reads the same balances file as the
seed command, so start the server with the same `BALANCES_FILE` if you named
one.

### The web page

With the API running, start the page from a second terminal:

```bash
cd frontend
npm install
npm run dev
```

Open `http://localhost:5173`. The page shows the balances, uploads a
transfers file, lists each transfer as completed or rejected, and shows the
history. A file that was already applied is not applied again until you
confirm. "Reset to opening balances" calls the reset route, which reseeds the
database. On a database that was never seeded, that button is how the page
loads the balances.

The page calls the API at `/api/...` on its own address, and the development
server passes those requests on to port 9292 (see `frontend/vite.config.ts`).

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

To use a database somewhere else, set `DATABASE_URL`, for example
`postgres://user:password@localhost/bank_test`. The specs for the domain and
for reading CSV files need no database. To run only those:

```bash
bundle exec rspec --tag '~database'
```

The page has its own tests, which need neither the API nor a database:

```bash
cd frontend
npm test
npm run lint
```

## Architecture

### Backend

The code is in `backend/lib/bank/` and follows Domain-Driven Design. It has
four layers, and each one only depends on the ones above it in this table.

| Layer             | What it does                                                                  |
|-------------------|-------------------------------------------------------------------------------|
| `domain/`         | The business rules: `Money`, `AccountNumber`, `Account` and `Transfer`.       |
| `application/`    | The operations the app performs, built from the domain objects.               |
| `infrastructure/` | Reads the CSV files, and stores the accounts and the history in Postgres.     |
| `interfaces/`     | The HTTP API. It calls the application services and returns JSON.             |

The domain layer is plain Ruby with no knowledge of files, the database or
HTTP, so the rules can be read and tested on their own.

There are two application services:

| Service            | What it does                                                             |
|--------------------|--------------------------------------------------------------------------|
| `SeedAccounts`     | Empties the accounts and the history, then stores one account for each line of the balances file. Seeds and reseeds. |
| `ProcessTransfers` | Refuses a file seen before, applies its transfers in order, completing or rejecting each one, and records them in the history. |

A posted transfers file goes through the layers like this:

1. `Interfaces::Api` reads the upload and passes the text to `Infrastructure::CsvFiles`,
   which splits it into rows and works out the file's fingerprint.
2. `Application::ProcessTransfers` checks the history for that fingerprint. Then it
   builds a `Transfer` from each row, finds the two accounts and asks the
   transfer to apply itself.
3. `ProcessTransfers` records every result in the history.
4. `Interfaces::Api` returns each result, and the balances, as JSON.

### Storage

The application services never talk to the database directly. They are handed two
objects from `infrastructure/`:

| Object              | Table       | What it keeps                                       |
|---------------------|-------------|-----------------------------------------------------|
| `AccountRepository` | `accounts`  | Each account number and its balance in whole cents. |
| `TransferHistory`   | `transfers` | One row per line of every uploaded transfers file.  |

The tables are created by the files in `backend/db/migrations/`, which the
server and the seed command both run when they start.

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
- **A transfers file is all or nothing if something breaks.** The balance
  changes and the history rows are saved in one database transaction. A
  rejected transfer is not a failure; a lost database connection is.
- **A repeated file is recognised by its contents.** The file has no transfer
  IDs, and two identical lines can be two real payments, so repeats cannot be
  spotted line by line. The SHA-256 hash of the whole file is stored with its
  history rows, and a file with a hash seen before is refused unless the
  sender confirms.
- **One transfers file is processed at a time.** Each upload takes a lock on
  the `transfers` table, so two uploads cannot both spend the same balance,
  and two copies of the same file cannot both be treated as new.

### Frontend

The page is a small React app in `frontend/src/`, written in TypeScript and
built with Vite.

| File                            | What it does                                                    |
|---------------------------------|-----------------------------------------------------------------|
| `api.ts`                        | Every call to the API. No other file uses `fetch`.              |
| `App.tsx`                       | The page: what it remembers, and what each button does.         |
| `components/AccountsTable.tsx`  | The table of balances.                                          |
| `components/TransfersTable.tsx` | The table of transfers, used for an upload's result and for the history. |
| `components/UploadForm.tsx`     | The file picker and its button.                                 |
| `format.ts`                     | Shows `4820.50` as `$4,820.50`, and a timestamp as a local time. |

The page holds no business rules. It never decides whether a transfer is
allowed or works out a balance: it shows what the API returns. Balances stay
as text from the database to the screen, so no float ever touches them.
