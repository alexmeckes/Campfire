# fixture-extra-long-run Retrospective

## Outcome

The benchmark reached a correct terminal stop at `m7_decision_stop` after validating six milestone transitions, one queue replenish, one explicit blocked stop, one explicit recovery path, and multiple resume surfaces.

## Highest-Signal Reusable Finding

### Control-plane candidate

- `start_slice.sh --from-next` advances the rolling queue but drops milestone-specific `acceptance_criteria` and `dependencies` for the new active milestone.
- In this benchmark, every auto-advanced milestone after `m1` required manual checkpoint repair before the evaluator could read the active contract from disk.
- That creates avoidable drift risk in long rolling runs because the task state is mechanically advanced but semantically incomplete until a manual follow-up edit fills the gap.

## Secondary Repo Lesson

- Fixture workspaces expose verifier, doctor, and resume wrappers locally, but the slice lifecycle helpers still need the repo-local skill scripts with `--root` to keep state mechanical.
- This is manageable in Campfire itself, but it is worth keeping explicit in benchmark/operator docs so workspace-local wrappers are not mistaken for a complete lifecycle surface.

## Smallest Useful Follow-up

- Add milestone metadata support to rolling queue entries or teach `start_slice.sh --from-next` to pull milestone contracts from a durable catalog, then add verifier coverage for queue-to-current contract preservation.
