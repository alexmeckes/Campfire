# m3 Resume Re-entry

## Goal

Show that the extra-long fixture can be re-entered from durable task state without spawning duplicate active work or losing the queued backlog.

## Re-entry Evidence

- `.autonomous/fixture-extra-long-run/artifacts/m3-resume.txt`
  - `resume_task.sh` rendered the active milestone as `m3_resume_reentry` with the active slice `capture-deliberate-resume-and-re-entry-evidence`.
  - The same render preserved the queued milestones `m4_queue_refresh`, `m5_blocker_gate`, `m6_recovery_report`, and `m7_decision_stop`.
  - No duplicate active slice was introduced; the helper explicitly reported that the task was already active on the persisted `m3` slice.
- `.autonomous/fixture-extra-long-run/artifacts/m3-doctor.txt`
  - `doctor_task.sh` still passed while the resumed slice was active.
- `.autonomous/fixture-extra-long-run/artifacts/m3-verify-fixture.txt`
  - The fixture verifier still passed, so the resume exercise did not corrupt the seeded benchmark surfaces.

## Resume Count

- `m1` baseline captured one resume render.
- `m2` captured a second resume render after auto-advancing.
- `m3` captures a third explicit resume render and is the first milestone whose purpose is resume fidelity itself.

## Conclusion

The fixture has now exercised multiple resume surfaces without losing the active milestone or queued backlog, satisfying the extra-long benchmark requirement for explicit resume/re-entry evidence.
