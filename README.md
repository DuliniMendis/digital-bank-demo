# Digital Bank Demo

A very simple banking service. It loads account balances for one company from a
CSV file, then applies a day's transfers from a second CSV file. A transfer is
rejected if it would take the sending account below $0.

This repository is being built one milestone at a time. Each milestone is one
pull request.

## Repository layout

```
backend/    Ruby: business rules, CSV import, database and HTTP API
frontend/   React app (added in a later milestone)
```

## Backend architecture

The backend follows Domain-Driven Design. It has four layers, and each layer
only depends on the layers above it in this table:

| Layer                           | What it holds                                            |
|---------------------------------|----------------------------------------------------------|
| `lib/bank/domain/`              | Business rules in plain Ruby. No files, database or HTTP. |
| `lib/bank/use_cases/`           | What the application does, using the domain.             |
| `lib/bank/infrastructure/`      | CSV files and database storage.                          |
| `lib/bank/web/`                 | The HTTP API.                                            |

Keeping the business rules in `domain/` means they can be read and tested
without a database or a web server.

## Domain model

| Class           | Kind         | What it is                                                        |
|-----------------|--------------|-------------------------------------------------------------------|
| `Money`         | Value object | An amount in whole cents. Never negative, never changes.          |
| `AccountNumber` | Value object | Exactly 16 digits. If one exists, it is valid.                    |
| `Account`       | Entity       | An account number and a balance. Refuses to go below $0.          |
| `Transfer`      | Value object | From, to and amount. Moves the money between two accounts.        |

A value object is defined by its contents: two `Money` objects of $5.00 are
equal. An entity is defined by its identity: two `Account` objects with the
same number are the same account, whatever their balance.

## Running the backend checks

Requires Ruby 4.0 (see `backend/.ruby-version`).

```bash
cd backend
bundle install
bundle exec rspec     # tests
bundle exec rubocop   # style checks
```

The same two commands run in GitHub Actions on every pull request
(`.github/workflows/ci.yml`).
