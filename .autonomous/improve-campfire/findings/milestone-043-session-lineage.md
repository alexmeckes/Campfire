# Milestone 043 Session Lineage

## Goal

Add lightweight session-lineage metadata so retries, course-corrected runs, and benchmark repro branches remain queryable in the existing SQL control plane.

## Acceptance Focus

- task sessions can record parent-child lineage for retries or course-corrected runs
- benchmark or retrospective evidence can point at specific run branches through a stable run identifier
- the design stays local, queryable, and compatible with the current single-agent Campfire workflow

## Next Slice

- extend session persistence with a stable run identifier and optional lineage metadata
- expose lineage in generated task context and improvement-candidate evidence paths
- add deterministic coverage for retry-style branching plus source-run linkage

## Validation Target

- targeted session-lineage checks in `campfire_sql.py` and the lifecycle helpers
- a deterministic verifier for parent-child retry lineage and source-run linkage
- `./scripts/verify_repo.sh`
