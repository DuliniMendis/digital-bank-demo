# Digital Bank Demo

A very simple banking service. It loads account balances for one company from a
CSV file, then applies a day's transfers from a second CSV file. A transfer is
rejected if it would take the sending account below $0.

It runs as a small server: the balances file is loaded when the server starts,
and each day's transfers file is posted to it.

This branch, `main`, is the answer to the brief and nothing more. A longer
version that adds a database is being built on the
[`extended`](../../tree/extended) branch.

## Try it

Requires Ruby 4.0 (see `backend/.ruby-version`).

**1. Start the server with a balances file**

```bash
cd backend
bundle install
BALANCES_FILE=spec/fixtures/account_balances.csv bundle exec rackup
```

The balances are loaded into memory and the server listens on
`http://localhost:9292`. If the balances file has a bad line, the server
refuses to start and names the line.

**2. Post a day's transfers** (from a second terminal, in `backend/`)

```bash
curl -F file=@spec/fixtures/transfers.csv http://localhost:9292/transfers
```

The response lists every transfer as `completed` or `rejected`, with the line
number and the reason for a rejection, followed by the balances afterwards:

```json
{
  "transfers": [
    { "line": 1, "from": "1111234522226789", "to": "1212343433335665",
      "amount": "500.00", "status": "completed", "reason": null }
  ],
  "accounts": [
    { "number": "1111234522226789", "balance": "4820.50" }
  ]
}
```

**3. See the current balances at any time**

```bash
curl http://localhost:9292/accounts
```

## The sample files

The two sample files from the brief are in `backend/spec/fixtures/`. Posting
the transfers file to a server started with the balances file gives:

| Account          | Starting balance | Final balance |
|------------------|-----------------:|--------------:|
| 1111234522226789 |          5000.00 |       4820.50 |
| 1111234522221234 |         10000.00 |       9974.40 |
| 2222123433331212 |           550.00 |       1550.00 |
| 1212343433335665 |          1200.00 |       1725.60 |
| 3212343433335755 |         50000.00 |      48679.50 |

All four transfers complete. A spec checks exactly this through the HTTP
endpoint (`backend/spec/bank/web/api_spec.rb`).

## File formats

Neither file has a header row.

| File      | Columns                            | Example                                    |
|-----------|------------------------------------|--------------------------------------------|
| Balances  | account number, balance            | `1111234522226789,5000.00`                 |
| Transfers | from account, to account, amount   | `1111234522226789,1212343433335665,500.00` |

## Assumptions

The brief leaves these open. Each one is covered by a spec.

**Transfers**

- Transfers are applied in file order, so a later transfer can spend money
  received by an earlier one.
- A transfer that would overdraw the sending account is rejected. Taking a
  balance to exactly $0 is allowed.
- A rejected transfer changes no balances and does not stop the transfers
  after it.
- A transfer is also rejected if either account does not exist, if both
  accounts are the same, if the amount is zero, or if the line cannot be read
  (bad account number, bad or missing amount).

**Balances**

- The starting balances must be trustworthy, so one bad line stops the whole
  load. The error names the line.
- An account number may appear only once in the balances file.
- An opening balance of $0 is allowed. A negative one is not.

**The server**

- Balances are loaded once, from the file named when the server starts. There
  is no endpoint to change them.
- Balances are kept in memory and carry over from one post to the next.
  Posting the same transfers file twice applies it twice.
- Restarting the server puts every account back to its starting balance.
- Transfers files are processed one at a time, even if two arrive together.

**Amounts and account numbers**

- An account number is exactly 16 digits.
- Amounts are dollars with up to two decimal places. `5.2` means $5.20;
  `5.100` is rejected rather than rounded.
- Amounts are stored as whole cents, never as decimal numbers, so arithmetic
  is exact.

## Architecture

All the code is in `backend/`. It follows Domain-Driven Design and is split
into four layers. Each layer only depends on the layers above it in this
table:

| Layer                      | What it holds                                             |
|----------------------------|-----------------------------------------------------------|
| `lib/bank/domain/`         | Business rules in plain Ruby. No files, database or HTTP. |
| `lib/bank/use_cases/`      | What the application does, using the domain.              |
| `lib/bank/infrastructure/` | CSV reading, and keeping the accounts in memory.          |
| `lib/bank/web/`            | The HTTP API. Turns requests into use-case calls.         |

Keeping the business rules in `domain/` means they can be read and tested
without a database or a web server.

### How a day's files flow through the layers

At startup:

1. `config.ru` asks `Web::Api` to load the balances file.
2. `Infrastructure::CsvFiles` splits the file into lines and columns. It does
   not judge the contents.
3. `UseCases::LoadAccounts` builds an `Account` from each line and adds it to
   the in-memory repository.

For each posted transfers file:

1. `Web::Api` reads the uploaded file and hands it to `CsvFiles`.
2. `UseCases::ProcessTransfers` builds a `Transfer` from each line, looks up
   the two accounts and asks the transfer to apply itself. Any broken business
   rule becomes a rejection with a reason.
3. `Web::Api` turns the results and the current balances into JSON.

## Domain model

| Class           | Kind         | What it is                                                 |
|-----------------|--------------|------------------------------------------------------------|
| `Money`         | Value object | An amount in whole cents. Never negative, never changes.   |
| `AccountNumber` | Value object | Exactly 16 digits. If one exists, it is valid.             |
| `Account`       | Entity       | An account number and a balance. Refuses to go below $0.   |
| `Transfer`      | Value object | From, to and amount. Moves the money between two accounts. |

A value object is defined by its contents: two `Money` objects of $5.00 are
equal. An entity is defined by its identity: two `Account` objects with the
same number are the same account, whatever their balance.

## Running the checks

```bash
cd backend
bundle exec rspec     # tests
bundle exec rubocop   # style checks
```

The same two commands run in GitHub Actions on every pull request
(`.github/workflows/ci.yml`).
