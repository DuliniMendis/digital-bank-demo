# Digital Bank Demo

A very simple banking service. It loads account balances for one company from a
CSV file, then applies a day's transfers from a second CSV file. A transfer is
rejected if it would take the sending account below $0.

This repository is being built one milestone at a time. Each milestone is one
pull request.

## The sample files

The two sample files from the brief are in `backend/spec/fixtures/`. An
end-to-end spec (`backend/spec/integration/sample_files_spec.rb`) loads the
balances, applies the transfers and checks the result:

| Account          | Starting balance | Final balance |
|------------------|-----------------:|--------------:|
| 1111234522226789 |          5000.00 |       4820.50 |
| 1111234522221234 |         10000.00 |       9974.40 |
| 2222123433331212 |           550.00 |       1550.00 |
| 1212343433335665 |          1200.00 |       1725.60 |
| 3212343433335755 |         50000.00 |      48679.50 |

All four transfers complete, and the total across all accounts stays at
$66,750.00.

To run it (requires Ruby 4.0, see `backend/.ruby-version`):

```bash
cd backend
bundle install                       # once, like `npm install`
bundle exec rake spec:integration
```

A transfer that cannot be applied is rejected with a reason, for example
`account 1111234522226789 does not have sufficient funds to withdraw $9999.00`,
and the remaining transfers still run.

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

**Amounts and account numbers**

- An account number is exactly 16 digits.
- Amounts are dollars with up to two decimal places. `5.2` means $5.20;
  `5.100` is rejected rather than rounded.
- Amounts are stored as whole cents, never as decimal numbers, so arithmetic
  is exact.

## Repository layout

```
backend/    Ruby: business rules, CSV import, and later the database and HTTP API
frontend/   React app (added in a later milestone)
```

## Backend architecture

The backend follows Domain-Driven Design. It is split into four layers, and
each layer only depends on the layers above it in this table:

| Layer                      | What it holds                                             |
|----------------------------|-----------------------------------------------------------|
| `lib/bank/domain/`         | Business rules in plain Ruby. No files, database or HTTP. |
| `lib/bank/use_cases/`      | What the application does, using the domain.              |
| `lib/bank/infrastructure/` | CSV reading and account storage.                          |
| `lib/bank/web/`            | The HTTP API (added in a later milestone).                |

Keeping the business rules in `domain/` means they can be read and tested
without a database or a web server.

### How a day's files flow through the layers

1. `Infrastructure::CsvFiles` splits each file into lines and columns. It does
   not judge the contents.
2. `UseCases::LoadAccounts` builds an `Account` from each balances line and
   adds it to the repository.
3. `UseCases::ProcessTransfers` builds a `Transfer` from each transfers line,
   looks up the two accounts and asks the transfer to apply itself. Any broken
   business rule becomes a rejection with a reason.
4. The caller gets back one result per transfer: completed, or rejected with
   the line number and the reason.

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

## Running the backend checks

The tasks are defined in `backend/Rakefile`. Rake is Ruby's task runner, like
the `scripts` section of a `package.json`.

```bash
cd backend
bundle exec rake                    # style check, then every spec
bundle exec rake spec               # every spec
bundle exec rake spec:integration   # only the sample files spec
bundle exec rake lint               # style check only
bundle exec rake -T                 # list all tasks
```

GitHub Actions runs `rake lint` and `rake spec` on every pull request
(`.github/workflows/ci.yml`).
