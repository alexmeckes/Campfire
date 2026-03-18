# Benchmark Fixture Workspaces

The canonical long and extra-long Campfire benchmarks should run inside dedicated fixture workspaces, not inside whichever product repo happens to be open.

Why:

- benchmark semantics should not inherit stale product history
- benchmark stop reasons should reflect Campfire behavior, not an unrelated repo objective boundary
- adapter comparisons should start from the same harness-shaped task state

The intended Pack v1 fixture layout is:

- `fixture-long-run/`
  - a neutral long-horizon backlog designed to force resume, queue replenish, validation, and at least one correct stop or reassess point
- `fixture-extra-long-run/`
  - a larger neutral backlog designed to run for hours and force multiple resumes, at least one blocker or failed validation, and a decision boundary

These fixture workspaces should stay repo-independent.

Good fixture work:

- evolve a small helper
- refactor a verifier
- update a generated projection
- handle a seeded blocker
- stop at a seeded decision boundary

Bad fixture work:

- finish a random product milestone
- continue a previously completed consumer-repo task
- rely on stale repo-specific context for success or failure

Real repo runs are still valuable, but they should be recorded as field validation rather than canonical benchmark scenarios.
