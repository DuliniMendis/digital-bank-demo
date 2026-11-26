# Notes for agents

Read this before changing anything. It holds what the code and the README do
not show: how the branches are used, what the owner has decided, and what to
leave alone. How to run and test the app is in `README.md`.

## What this project is

A take-home banking challenge that was then extended into a small full app.
The owner is new to Ruby and has to explain every line in an interview, so
simple code matters more here than clever code.

## Branches

- **`main` is the submission.** It is the simplest version that answers the
  brief: domain, CSV import, application services, in-memory storage and a
  small Sinatra server. It has no database and no locking, on purpose.
- **`extended` holds everything beyond the brief**: Postgres, the `/api`
  routes, the React page and the Vercel deployment.
- **Extension work never goes into `main`.** Its pull requests target
  `extended`.
- **Changes to `main` reach `extended` through a pull request of their own**
  that only merges `main` into `extended`. Keeping that separate stops a
  feature pull request from showing changes that were already reviewed.
  When the two conflict, keep the database version on `extended`.
- **The two branches lay their files out differently.** `main` keeps the
  Ruby app at the repository root. `extended` keeps it in `backend/`, because
  it has `frontend/` beside it.
- **A merge of `main` into `extended` must leave the Ruby app in `backend/`.**
  Git follows an edit to an existing file into `backend/` by itself. For a
  new file from `main` it stops with a "file location" conflict and suggests
  the path inside `backend/`, which is the one to accept. Check that nothing
  from the Ruby app ended up at the root before committing the merge.
- **Each branch has its own `AGENTS.md`.** The one on `main` leaves out what
  only applies here. In a merge of `main` into `extended`, keep this one.
- **`main`'s README and CI workflow assume the root layout.** Do not copy
  their paths or their missing `cd backend` lines into `extended`.

## Working with the owner

- **One pull request per piece of work, then stop.** Do not merge a pull
  request without the owner saying so for that pull request. The one
  exception is a pull request that only merges `main` into `extended`.
- **Re-read a pull request's base branch right before merging it.** GitHub
  deletes a merged branch and points the pull requests stacked on it at the
  branch below, so the base can change while you work.
- **Do not add code or specs nobody asked for.** Suggest them first.
- **Report what was not checked.** Say plainly when something was only
  covered by tests, or not run at all.

## Things that must stay out of the repository

- **The original brief and its two sample CSV files.** They sit untracked in
  the repository root. Never commit them.
- **The name of the company that set the challenge.** It must not appear in
  code, documentation, branch names or project names.

## Code conventions

- **Keep Ruby plain.** Prefer fewer classes and files. Do not wrap a class in
  another class that has only one caller.
- **Layers follow Domain-Driven Design**: `domain`, `application`,
  `infrastructure`, `interfaces`. Write "application service", not "use
  case".
- **Money is whole cents inside the code and text in JSON.** Never a float.
- **Each rule lives in one place.** A broken rule raises a `Domain::Error`.
- **Do not write a spec that is harder to explain than the risk it guards.**
  A spec that needs threads and sleeps to prove a lock was removed for that
  reason. Say the behaviour is untested instead.

## Comments

- Write full sentences that tell the reader something the code does not: a
  reason, a consequence, or a surprising behaviour.
- Do not restate a name, and do not explain Ruby or a library.
- Do not name another file's path, another class, or a list that is defined
  elsewhere. Such comments go stale when the other thing changes.
- Aim for one to three sentences. Fragments such as "Sixteen digits." are too
  short to be useful.

## Decisions on `extended` that should not be undone

- **The database is the only storage.** There is no in-memory repository.
- **The server never loads balances when it starts.** The seed command and
  the reset route are the two ways balances get in, and both call
  `SeedAccounts`.
- **A transfers file posted twice is applied twice.** Protection against
  repeats was built and then removed.
- **There is no history of past uploads.** It was built and then removed. The
  page shows the result of the latest upload and nothing older.

## Frontend conventions

- **`App.tsx` keeps the state and what the buttons do.** Each part of the
  page is its own component in `src/components/`.
- **Files that are not components go in `src/lib/`.** Only `lib/api.ts` calls
  `fetch`.
- **The page holds no business rules.** It shows what the API returns.
- **ESLint is the linter**, and there is one `tsconfig.json`. TypeScript
  stays on 6.0 until typescript-eslint supports 7.0.

## Databases and migrations

- **Do not edit or delete a migration that has already run somewhere.** Every
  database that ran it then refuses to start, and has to be fixed by hand.
  Add a new migration instead.
- **Tests must never touch a database that holds anything worth keeping.**
  Use a local database made for the purpose.

## The live demo

- **A merge into `extended` goes live.** The `deploy` job in the CI workflow
  deploys to production once the other jobs pass, so treat merging as
  deploying.
- **Do not connect the GitHub repository to Vercel.** The deploy job uses the
  Vercel CLI with a token kept as a GitHub secret. A Git connection as well
  would deploy every merge twice, and would build previews of pull requests
  that share the live database.
- **Never test against the live demo.** Do not upload files to it or reset
  it. Reading its pages is fine.
- **A deploy by hand still needs the owner's go-ahead, and a clean checkout
  of `extended`.** The Vercel CLI uploads untracked files that `.gitignore`
  does not list, which would include the original brief.
- **The first deployment of a new Vercel project goes to production**, even
  without `--prod`.

## Sharing this machine

- **Other sessions may use the same checkout** and switch its branch. Check
  the branch before committing, or work in a git worktree.
- **Check a port is free before starting a server on it**, and stop only the
  process you started.
