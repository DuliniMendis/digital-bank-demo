# Digital Bank Demo

This is a small banking service written in Ruby. It loads account balances
for one company from a CSV file, then applies a day's transfers from a second
CSV file. A transfer that would take the sending account below $0 is
rejected.

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

A bad line in the balances file stops the server from starting. The error
gives the line number and says what is wrong with it.

From a second terminal, post a day's transfers:

```bash
curl -F file=@spec/fixtures/transfers.csv http://localhost:9292/transfers
```

The response lists every transfer with its line number and whether it was
`completed` or `rejected`, followed by the balances afterwards. This is the
response to the sample file, shortened to one transfer and one account:

```json
{
  "transfers": [
    {
      "line": 1,
      "from": "1111234522226789",
      "to": "1212343433335665",
      "amount": "500.00",
      "status": "completed",
      "reason": null
    }
  ],
  "accounts": [
    { "number": "1111234522226789", "balance": "4820.50" }
  ]
}
```

A rejected transfer has `"status": "rejected"`, and its `reason` says why,
for example `account 1111234522226789 does not have sufficient funds to
withdraw $5000.01`.

To see the balances at any time:

```bash
curl http://localhost:9292/accounts
```

### Good to know

- **The file formats.** Each line of the balances file is
  `account number,balance`, and each line of the transfers file is
  `from,to,amount`. A header row is optional in both. Sample files are in
  `spec/fixtures/`.
- **Balances are kept in memory.** They carry over from one post to the next
  and only go back to their starting values when the server restarts.
- **The same file can be posted twice.** A second post is applied as a second
  set of transfers, on purpose, because two files with the same lines can
  both be genuine.
- **There are files of awkward input to try.** They are in
  `spec/fixtures/edge_cases/`, and the name of each file says what happens
  when it is posted to a freshly started server.

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

## An option: settling at the end

By default each transfer has to be affordable at the moment it is applied. To
check the balances only once, after the whole file, add `settle_at_end`:

```bash
curl -F file=@spec/fixtures/transfers.csv -F settle_at_end=true http://localhost:9292/transfers
```

Each account first receives everything coming to it in the file and then pays
out everything leaving it, so a transfer may spend money that arrives later
in the file and the order of the lines no longer matters.

It is all or nothing. Every account is checked before any balance changes,
and if the file would leave any account below $0, nothing in it is applied
and every transfer in it is rejected with that reason. A line that cannot be
read, or that names an unknown account, is still rejected by itself.

`Account` owns this rule too, next to the one for a single withdrawal.

## Beyond the brief

This branch is the simplest version that answers the brief. The `extended`
branch builds on it with the things a real service would need:

- **A web page**, built with React, for uploading a file and seeing the
  balances and the result of that upload.
- **A live deployment**, hosted on Vercel at
  <https://digital-bank-demo-flame.vercel.app>.
- **A Postgres database**, hosted by Neon through Vercel, so balances
  survive a restart.
- **Locking, so uploads that arrive together are safe.** Each transfer runs
  in a database transaction, which is rolled back if either the withdrawal or
  the deposit fails.
- **React component tests and end-to-end tests**, built with React Testing
  Library, Vitest and Playwright.

Locking was left out of this branch on purpose. The server here can handle
two requests at once, so two uploads arriving at the same moment could both
spend the same balance. A database solves that properly with transactions and
row locks.

The hosted version is the quickest way to try the `extended` branch. To run
it yourself, follow the
[README on the `extended` branch](https://github.com/DuliniMendis/digital-bank-demo/blob/extended/README.md).
