# Ledger Lab

Practice project: a multi-currency double-entry ledger. Rails 8.1 (Ruby 4.0) + PostgreSQL + Sidekiq.
A JSON REST API is the interface; frontends come later, as needed.
Money correctness comes first; everything else is kept simple.

## Money rules (non-negotiable)
- Amounts are integers in minor units (`amount_cents`). Never float or `to_f`.
- One currency per entry. FX = two entries.
- Each transaction's entries sum to zero per currency.
- The ledger is append-only: fix with a reversal, never update or delete entries.
- Every transaction has an idempotency key with a unique DB index.
- Debits lock the account row (`lock!`) inside the transaction.

## Commands
- Tests: `bin/rspec` (one: `bin/rspec spec/path/to_spec.rb:55`)
- Lint: `bin/rubocop -a` on the files you changed
- Before finishing: full `bin/rspec` green, rubocop clean, `bin/rails zeitwerk:check`.

## Structure
- Business logic and every create/update/delete live in `app/services/<namespace>/<action>_service.rb`,
  named `<Namespace>::<Action>Service`, called as `Service.call(...)`.
- Controllers stay slim: validate params, call the service, render.
- Inside a DB transaction, enqueue jobs in `after_commit`, never with a plain `perform_later`.
- Roll back by raising; `ActiveRecord::Rollback` is ignored inside an outer transaction.
- Jobs are idempotent: running twice must change nothing.
- No new gems without asking.

## JSON API
- Versioned under `/api/v1`. Controllers in `app/controllers/api/v1/`, inheriting `Api::V1::BaseController < ActionController::API`.
- Resources are plural nouns (`/accounts`, `/transactions`); entries are read-only, nested under their transaction.
- Money in and out is `{"amount_cents": 1050, "currency": "EUR"}`: integer cents plus ISO 4217 code. Never decimals or strings for amounts.
- Writes that move money require an `Idempotency-Key` header. Same key + same body → return the original result; same key + different body → `409`.
- Status codes: `201` created, `200` ok, `404` not found, `409` idempotency conflict, `422` validation or business rule (e.g. insufficient funds).
- Errors have one shape: `{"error": {"code": "insufficient_funds", "message": "...", "details": {}}}`. The `code` is stable; the message can change.
- Serialize with plain classes in `app/serializers/` (no serializer gems). Never render a model with `render json: record`.
- Lists are ordered and paginated by cursor (`?after=<id>&limit=50`, max 100).
- No authentication yet. TODO when a frontend needs it.
- Every endpoint has a request spec in `spec/requests/api/v1/` covering success, validation error and not found.

## Database
- Generate migrations with `bin/rails g migration`. Keep them reversible.
- Constraints in the DB (NOT NULL, FK, unique, CHECK), not only Rails validations.
- Every list query has an explicit order when the record picked matters.

## Specs
- `spec/` mirrors `app/`. Name the subject: `subject(:result) { described_class.call(...) }`.
- Bug fix = a spec that fails without the fix.
- Cover the error paths and the negative case.
- Never mock the ledger or the DB in money specs.
- Concurrency rules (locks, idempotency) get a spec that runs two attempts.
- Freeze time with `freeze_time` / `travel_to`.

## Review checklist
- Concurrency: the same request twice, two writes on one record. Guarantees rest on a lock or a unique index, not a check before the write.
- Errors: rescue the narrowest exception, and spec it.
- Callers of a changed method still get what they expect.
- No reference to a class, constant or column that doesn't exist.

## What the agent gets wrong here
- Made-up gem methods: check the code before using one.
- `rescue => e` without re-raising.
- <add when something happens twice and no spec or rule catches it>
