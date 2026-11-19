# Digital Bank Demo

A very simple banking service. It loads account balances for one company from a
CSV file, then applies a day's transfers from a second CSV file. A transfer is
rejected if it would take the sending account below $0.

This repository is being built one milestone at a time. Each milestone is one
pull request.

## Try it

Requires Ruby 4.0 (see `backend/.ruby-version`).

```bash
cd backend
bundle install
bin/process_transfers examples/account_balances.csv examples/transfers.csv
```

```
Final balances
  1111234522226789       4820.50
  1111234522221234       9974.40
  2222123433331212       1550.00
  1212343433335665       1725.60
  3212343433335755      48679.50

Transfers: 4 completed, 0 rejected
```

A transfer that cannot be applied is listed with its line number and the
reason, and the remaining transfers still run:

```
Rejected transfers
  line 1: 1111234522226789 -> 1212343433335665 9999.00: account 1111234522226789 does not have sufficient funds to withdraw $9999.00
```

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
backend/    Ruby: business rules, CSV import, command-line runner
frontend/   React app (added in a later milestone)
```

## Backend architecture

The backend follows Domain-Driven Design. It is split into layers, and each
layer only depends on the layers above it in this table:

| Layer                      | What it holds                                             |
|----------------------------|-----------------------------------------------------------|
| `lib/bank/domain/`         | Business rules in plain Ruby. No files, database or HTTP. |
| `lib/bank/use_cases/`      | What the application does, using the domain.              |
| `lib/bank/infrastructure/` | CSV reading and account storage.                          |
| `lib/bank/cli.rb`, `web/`  | Entry points: the command line and (later) the HTTP API.  |

Keeping the business rules in `domain/` means they can be read and tested
without a database or a web server.

### How one run flows through the layers

1. `bin/process_transfers` calls `Bank::CLI` with the two file paths.
2. `Infrastructure::CsvFiles` splits each file into lines and columns. It does
   not judge the contents.
3. `UseCases::LoadAccounts` builds an `Account` from each balances line and
   adds it to the repository.
4. `UseCases::ProcessTransfers` builds a `Transfer` from each transfers line,
   looks up the two accounts and asks the transfer to apply itself. Any broken
   business rule becomes a rejection with a reason.
5. `CLI::Report` prints the final balances and the rejected transfers.

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

```bash
cd backend
bundle exec rspec     # tests
bundle exec rubocop   # style checks
```

The same two commands run in GitHub Actions on every pull request
(`.github/workflows/ci.yml`).
