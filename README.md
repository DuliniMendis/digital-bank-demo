# Digital Bank Demo

A small banking service. It loads account balances for one company from a CSV
file, then applies a day's transfers from a second CSV file. A transfer that
would take the sending account below $0 is rejected.

This is the `extended` branch. The `main` branch is the simplest version that
answers the brief and keeps everything in memory. On this branch the accounts
are kept in a Postgres database, and there is a web page to use it from.

```
backend/    Ruby: the business rules, the database and the HTTP API
frontend/   React: the web page
```

## Running it

Requires Ruby 3.3 or newer, Node 26 and a running Postgres.

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

By default each transfer has to be affordable at the moment it is applied. To
check the balances only once, after the whole file, add `settle_at_end`:

```bash
curl -F file=@spec/fixtures/transfers.csv -F settle_at_end=true http://localhost:9292/api/transfers
```

A transfer may then spend money that arrives later in the file. If the file
would leave any account below $0, nothing in it is applied, and every transfer
in it is rejected with that reason.

Nothing stops the same transfers file being posted twice, and that is on
purpose. A second post is applied as a second set of transfers, because two
files with the same lines can both be genuine.

The other routes:

```bash
curl http://localhost:9292/api/accounts                 # the current balances
curl -X POST http://localhost:9292/api/reset            # reseeds: puts the opening balances back
curl http://localhost:9292/api/samples                  # the names of the sample transfers files
curl http://localhost:9292/api/samples/transfers.csv    # one of them, as a download
```

A header row is optional in both CSV files. A balances line is
`account number,balance` and a transfers line is `from,to,amount`. Sample
files are in `backend/spec/fixtures/`.

Balances are kept in the database, so they are still there after the server
restarts. To go back to the opening balances, reseed: either post to the reset
route or run the seed command again. Both replace whatever accounts the
database holds. The reset route reads the same balances file as the seed
command, so start the server with the same `BALANCES_FILE` if you named one.

### The web page

With the API running, start the page from a second terminal:

```bash
cd frontend
npm install
npm run dev
```

Open `http://localhost:5173`. The page shows the balances, uploads a
transfers file, and lists each transfer in it as completed or rejected. That
result stays on the page until the next upload, a reset or a reload; nothing
keeps a history of past uploads. Ticking "Check balances only at the end of
the file" sends `settle_at_end` with the next upload. "Reset to opening
balances" calls the reset route, which reseeds the database. On a database
that was never seeded, that button is how the page loads the balances.

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

To use a test database somewhere else, set `DATABASE_URL`, for example
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

There are also a few end-to-end tests, written with Playwright. They open the
page in a real browser and use it against the real API and a real database,
to check that the three work together. Playwright starts the API and the page
itself, on ports of their own, so nothing else needs to be running:

```bash
cd frontend
createdb bank_e2e                     # once
npx playwright install chromium       # once: downloads the browser
npm run e2e
```

Every test resets its database, which is why they use `bank_e2e` and not the
development one. To use a database somewhere else, set `E2E_DATABASE_URL`.

## Architecture

### Backend

The code is in `backend/lib/bank/` and follows Domain-Driven Design. It has
four layers, and each one only depends on the ones above it in this table.

| Layer             | What it does                                                                |
|-------------------|-----------------------------------------------------------------------------|
| `domain/`         | The business rules: `Money`, `AccountNumber`, `Account` and `Transfer`.     |
| `application/`    | The operations the app performs, built from the domain objects.             |
| `infrastructure/` | Reads the CSV files, and stores the accounts in Postgres.                   |
| `interfaces/`     | The HTTP API. It calls the application services and returns JSON.           |

The domain layer is plain Ruby with no knowledge of files, the database or
HTTP, so the rules can be read and tested on their own.

There are two application services:

| Service            | What it does                                                            |
|--------------------|-------------------------------------------------------------------------|
| `SeedAccounts`     | Replaces the stored accounts with one for each line of the balances file. Used to seed and to reseed. |
| `ProcessTransfers` | Applies a list of transfers in order, completing or rejecting each one. |

A posted transfers file goes through the layers like this:

1. `Interfaces::Api` reads the upload and passes the text to `Infrastructure::CsvFiles`,
   which splits it into rows.
2. `Application::ProcessTransfers` builds a `Transfer` from each row, finds the two
   accounts and asks the transfer to apply itself.
3. `Interfaces::Api` returns each result, and the balances, as JSON.

### Storage

The application services never talk to the database directly. They are handed a
*repository*, `AccountRepository`, which adds, finds and saves
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
  longer matters. A line that cannot be read, or that names an unknown
  account, is still rejected by itself. `Account` owns this rule too, next to
  the one for a single withdrawal. The whole file runs in one database
  transaction, with each account's row locked from the moment it is looked up
  until the new balances are saved.
- **A transfer is all or nothing.** Each one runs in its own database
  transaction, so both balances are saved or neither is. Seeding works the
  same way for the whole balances file.
- **Two transfers cannot both spend the same balance.** Looking up an account
  for a transfer locks its row in the database until that transfer is saved.

### Frontend

The page is a small React app in `frontend/src/`, written in TypeScript and
built with Vite.

| File            | What it does                                                                       |
|-----------------|------------------------------------------------------------------------------------|
| `App.tsx`       | The page: what it remembers, what each button does, and the order of its sections. |
| `lib/api.ts`    | Every call to the API. No other file uses `fetch`.                                 |
| `lib/format.ts` | Shows `4820.50` as `$4,820.50`.                                                    |

`App.tsx` hands what it remembers to the components in `components/`, one for
each part of the page:

| Component         | What it shows                                                        |
|-------------------|----------------------------------------------------------------------|
| `PageHeader`      | The title and the reset button.                                      |
| `AccountsSection` | The balances, in an `AccountsTable`.                                 |
| `UploadSection`   | The `UploadForm` (file picker and button), the `SamplePicker` (list of sample files and button) and the `UploadResult` of the last upload. |
| `TransfersTable`  | The table of transfers inside the upload result.                     |
| `Spinner`         | The turning ring shown while the page waits for the API.             |

The page holds no business rules. It never decides whether a transfer is
allowed or works out a balance: it shows what the API returns. Balances stay
as text from the database to the screen, so no float ever touches them.

## Deployment

The app is live at <https://digital-bank-demo-flame.vercel.app>. Its database
was seeded with the sample balances, and "Reset to opening balances" puts
them back.

The page and the API are deployed together as one Vercel project, so they
share one address and every deployment contains matching versions of both.

| File                 | What it does                                                           |
|----------------------|------------------------------------------------------------------------|
| `vercel.json`        | Declares the two services, and sends `/api/...` to the backend and everything else to the page. |
| `backend/Dockerfile` | Builds the Ruby API into a container image.                            |

The backend runs as a container because Vercel's built-in Ruby runtime cannot
load the Postgres driver. The frontend needs no configuration: Vercel
recognises a Vite project and builds it.

The database is a free Neon Postgres, added to the project through the Vercel
Marketplace. That sets `DATABASE_URL` on the project, which is the one setting
the API needs. With no `BALANCES_FILE` set, a reset loads the sample balances.

A new database is empty. The server creates the tables but loads no balances,
so the page shows no accounts until the database is seeded. Pressing "Reset to
opening balances" on the page does that. So does running the seed command
with `DATABASE_URL` pointing at the hosted database.

Two things follow from how containers run on Vercel:

- **A container is started when a request arrives and stopped when it has been
  idle.** Nothing can be kept in the container's memory or on its disk, which
  is why the accounts are in Postgres.
- **Every start runs `config.ru`**, so the table is created on the first
  start and left alone on later ones.

A merge into `extended` is deployed automatically. The `deploy` job in
`.github/workflows/ci.yml` runs after the tests pass and puts the merge into
production with the Vercel CLI. It reads three settings from the GitHub
repository:

| Setting             | Kind     | What it is                                    |
|---------------------|----------|-----------------------------------------------|
| `VERCEL_TOKEN`      | Secret   | A Vercel access token, which lets the job deploy. |
| `VERCEL_ORG_ID`     | Variable | The Vercel account the project belongs to.    |
| `VERCEL_PROJECT_ID` | Variable | The Vercel project to deploy to.              |

The GitHub repository is not connected to Vercel in any other way, so pull
requests and pushes to `main` deploy nothing.

To deploy by hand instead, from the repository root:

```bash
vercel deploy          # a preview
vercel deploy --prod   # production
```
