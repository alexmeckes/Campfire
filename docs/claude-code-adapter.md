# Claude Code Adapter

## Purpose

Campfire should support Claude Code through a thin adapter layer, not by adding Claude-specific behavior to Campfire core.

This note defines the smallest useful Claude Code integration:

- project-local slash commands under `.claude/commands/`
- project hooks wired through `.claude/settings.json`
- one optional status line command

The goal is to make Claude Code behave well in a Campfire repo without turning Campfire into a Claude-only framework.

Relevant Claude Code docs:

- [Claude Code slash commands](https://docs.anthropic.com/en/docs/claude-code/tutorials)
- [Claude Code hooks](https://docs.anthropic.com/en/docs/claude-code/hooks)
- [Claude Code settings](https://docs.anthropic.com/en/docs/claude-code/settings)
- [Claude Code status line](https://docs.anthropic.com/en/docs/claude-code/statusline)

## Design Rule

Campfire stays editor- and agent-agnostic.

The Claude Code adapter should:

- read the existing Campfire control plane
- call the existing Campfire scripts
- expose Claude-native entry points

It should not:

- add a second control plane
- duplicate Campfire state in `.claude/`
- invent Claude-only task semantics

## Folder Layout

Recommended project-local layout:

```text
.claude/
  settings.json
  commands/
    campfire-resume.md
    campfire-new-task.md
    campfire-start-slice.md
    campfire-complete-slice.md
    campfire-retro.md
  hooks/
    campfire-session-start.sh
    campfire-pre-tool.sh
    campfire-post-tool.sh
    campfire-statusline.sh
```

Optional later additions:

```text
.claude/
  commands/
    campfire-adopt.md
  hooks/
    campfire-session-end.sh
```

The Campfire repo ships a working starter template in [examples/basic-workspace/.claude](/Users/alexmeckes/Downloads/Campfire/examples/basic-workspace/.claude).

## Commands

Claude Code project commands should stay thin. They should mostly route the operator into the existing Campfire helpers.

### `/campfire-resume`

Purpose:

- detect the repo task root
- show the current active or resumable task
- emit the current Campfire resume prompt

Command body should roughly instruct Claude to:

1. run `./scripts/resume_task.sh <task-slug>`
2. read the emitted task and project context
3. continue from the current slice or stop if the task is waiting on a real decision

### `/campfire-new-task`

Purpose:

- bootstrap a new Campfire task in a repo that already has Campfire installed

Expected flow:

1. run `./scripts/new_task.sh "$ARGUMENTS"` or the repo-local equivalent
2. inspect the created task state
3. suggest the first bounded framing step

### `/campfire-start-slice`

Purpose:

- make slice activation explicit before Claude starts editing files

Expected flow:

1. identify the current queued or active milestone
2. run `./scripts/start_slice.sh ...`
3. continue only after the task is in `in_progress`

### `/campfire-complete-slice`

Purpose:

- close the loop mechanically after validation

Expected flow:

1. summarize what was validated
2. run `./scripts/complete_slice.sh ...`
3. refresh the task state and handoff

### `/campfire-retro`

Purpose:

- run the retrospective pass after a completed or failed slice

Expected flow:

1. inspect the task outcome and validation evidence
2. run the Campfire retrospective process
3. record improvement candidates if needed

## Hooks

The first adapter should use only three hooks plus one status line command. The current Campfire example template now includes all three hook categories plus the status line.

### `campfire-session-start.sh`

Wire through `SessionStart`.

Purpose:

- detect whether the current repo has Campfire
- detect the configured task root
- find the most relevant active or resumable task
- inject a short context block into Claude Code at session start

Input:

- Claude Code `SessionStart` JSON from stdin

Behavior:

1. resolve the project dir from hook input
2. if no `campfire.toml` or `.campfire/` exists, emit no additional context
3. if Campfire exists, read:
   - `.campfire/project_context.json` when present
   - the most relevant task context when present
4. emit a short `additionalContext` block with:
   - current task slug
   - status
   - milestone
   - stop reason
   - suggested next helper

The context should stay short enough to avoid recreating the old prompt-bloat problem.

### `campfire-pre-tool.sh`

Wire through `PreToolUse` for `Edit|MultiEdit|Write|Bash`.

Purpose:

- enforce the smallest useful Campfire guardrail in Claude Code

Implemented template behavior:

1. if the repo is not using Campfire, allow
2. if Campfire is present but there is no active task, allow with no intervention
3. if there is an active task but no active slice and Claude is about to edit files, block with a short reason:
   - start a slice first
4. if the task is `waiting_on_decision`, block edit/write tools and tell Claude to stop on the decision boundary

This should stay narrow. It should not try to become a full scheduler.

### `campfire-post-tool.sh`

Wire through `PostToolUse` for `Edit|MultiEdit|Write|Bash`.

Purpose:

- keep heartbeat and projections reasonably fresh during Claude sessions

Implemented template behavior:

1. if the repo is not using Campfire, exit
2. if there is an active task, call the existing Campfire helper path to:
   - touch heartbeat
   - refresh registry and projections when appropriate
3. avoid heavy or blocking work

This hook should be safe to run often. If it becomes too expensive, it should be reduced rather than made smarter.

### `campfire-statusline.sh`

Wire through `statusLine` in `.claude/settings.json`.

Purpose:

- surface the current Campfire state continuously without extra prompt text

Suggested output:

- task slug
- milestone id
- heartbeat state
- run mode

Example:

```text
campfire improve-campfire m-050 waiting_on_decision rolling
```

This is one of the cheapest, highest-signal adapter surfaces.

## Sample `.claude/settings.json`

Example project-level configuration:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR/.claude/hooks/campfire-session-start.sh\""
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Edit|MultiEdit|Write|Bash",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR/.claude/hooks/campfire-pre-tool.sh\""
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|MultiEdit|Write|Bash",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR/.claude/hooks/campfire-post-tool.sh\""
          }
        ]
      }
    ]
  },
  "statusLine": {
    "type": "command",
    "command": "\"$CLAUDE_PROJECT_DIR/.claude/hooks/campfire-statusline.sh\"",
    "padding": 0
  }
}
```

The command paths should stay project-local so the adapter can live inside a consumer repo without requiring global user setup.

## Why This Is Enough

This adapter gives Claude Code the four things it actually needs:

- a low-friction entry point
- lightweight guardrails before edits
- lightweight state refresh after edits
- passive visibility during long runs

That is enough to make Campfire usable in Claude Code without expanding Campfire core.

## Non-Goals

- no Claude-specific task state
- no new database
- no mandatory MCP server
- no Claude-only automation semantics
- no automatic skill generation inside Claude Code

If deeper Claude integration is needed later, it should still start as an extension layered on top of this adapter.
