# milestone-018 rolling events fix

- Rolling runs were still using `auto_advanced` and `auto_reframed` as terminal stop reasons in examples and verifiers.
- The contract now records those transitions in `last_run.events` and reserves `last_run.stop_reason` for the actual terminal pause reason.
- The rolling execution and rolling reframe verifiers now prove that a run can continue after those transitions and only pause later for a real reason such as `manual_pause`.
