#!/bin/zsh
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BOOTSTRAP_SCRIPT="$SKILL_DIR/scripts/bootstrap_task.sh"
INIT_SCRIPT="$SKILL_DIR/scripts/init_task.sh"
RESUME_SCRIPT="$SKILL_DIR/scripts/resume_task.sh"
SELF_SCRIPT="$SKILL_DIR/scripts/verify_worktree_bootstrap.sh"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

expect_file() {
  local path="$1"
  [ -e "$path" ] || fail "Missing required path: $path"
}

expect_contains() {
  local path="$1"
  local pattern="$2"
  if ! /usr/bin/grep -q "$pattern" "$path"; then
    fail "Expected pattern '$pattern' in $path"
  fi
}

echo "== Syntax checks =="
zsh -n "$BOOTSTRAP_SCRIPT" "$INIT_SCRIPT" "$RESUME_SCRIPT" "$SELF_SCRIPT"

echo "== Git worktree bootstrap simulation =="
TEMP_ROOT="$(mktemp -d)"
TEMP_ROOT_CANON="$(cd "$TEMP_ROOT" && pwd)"
trap 'rm -rf "$TEMP_ROOT" /tmp/campfire_worktree_bootstrap.out /tmp/campfire_worktree_resume.out /tmp/campfire_fallback_bootstrap.out /tmp/campfire_fallback_resume.out /tmp/campfire_git_init.out /tmp/campfire_git_commit.out' EXIT
GIT_REPO="$TEMP_ROOT/git-repo"
mkdir -p "$GIT_REPO"
git -C "$GIT_REPO" init >/tmp/campfire_git_init.out 2>&1
git -C "$GIT_REPO" config user.name "Campfire Test"
git -C "$GIT_REPO" config user.email "campfire@example.com"
echo "# temp repo" > "$GIT_REPO/README.md"
git -C "$GIT_REPO" add README.md
git -C "$GIT_REPO" commit -m "Initial commit" >/tmp/campfire_git_commit.out 2>&1
git -C "$GIT_REPO" branch -M main

TASK_SLUG="verify-worktree-bootstrap"
WORKTREE_PATH="$TEMP_ROOT_CANON/git-repo-worktrees/$TASK_SLUG"

"$BOOTSTRAP_SCRIPT" \
  --root "$GIT_REPO" \
  --slug "$TASK_SLUG" \
  --worktree \
  "verify git worktree bootstrap handling" >/tmp/campfire_worktree_bootstrap.out

expect_file "$WORKTREE_PATH/.autonomous/$TASK_SLUG/checkpoints.json"
expect_contains /tmp/campfire_worktree_bootstrap.out 'strategy: git_worktree'
expect_contains /tmp/campfire_worktree_bootstrap.out 'workspace:'
expect_contains "$WORKTREE_PATH/.autonomous/$TASK_SLUG/checkpoints.json" '"strategy": "git_worktree"'
expect_contains "$WORKTREE_PATH/.autonomous/$TASK_SLUG/checkpoints.json" "\"branch\": \"codex/$TASK_SLUG\""
expect_contains "$WORKTREE_PATH/.autonomous/$TASK_SLUG/runbook.md" 'Workspace strategy: git_worktree'
expect_contains "$WORKTREE_PATH/.autonomous/$TASK_SLUG/runbook.md" "Branch: codex/$TASK_SLUG"
expect_contains "$GIT_REPO/.git/worktrees/$TASK_SLUG/gitdir" "$WORKTREE_PATH/.git"

"$RESUME_SCRIPT" --root "$WORKTREE_PATH" "$TASK_SLUG" >/tmp/campfire_worktree_resume.out

expect_contains /tmp/campfire_worktree_resume.out 'Workspace strategy:'
expect_contains /tmp/campfire_worktree_resume.out 'strategy: git_worktree'
expect_contains /tmp/campfire_worktree_resume.out "branch: codex/$TASK_SLUG"

echo "== Non-git fallback simulation =="
FALLBACK_ROOT="$TEMP_ROOT/non-git-root"
mkdir -p "$FALLBACK_ROOT"
FALLBACK_SLUG="verify-worktree-fallback"

"$BOOTSTRAP_SCRIPT" \
  --root "$FALLBACK_ROOT" \
  --slug "$FALLBACK_SLUG" \
  --worktree \
  "verify non-git fallback handling" >/tmp/campfire_fallback_bootstrap.out

expect_file "$FALLBACK_ROOT/.autonomous/$FALLBACK_SLUG/checkpoints.json"
expect_contains /tmp/campfire_fallback_bootstrap.out 'falling back to in-place task setup'
expect_contains /tmp/campfire_fallback_bootstrap.out 'strategy: in_place'
expect_contains "$FALLBACK_ROOT/.autonomous/$FALLBACK_SLUG/checkpoints.json" '"strategy": "in_place"'
expect_contains "$FALLBACK_ROOT/.autonomous/$FALLBACK_SLUG/runbook.md" 'Workspace strategy: in_place'

"$RESUME_SCRIPT" --root "$FALLBACK_ROOT" "$FALLBACK_SLUG" >/tmp/campfire_fallback_resume.out

expect_contains /tmp/campfire_fallback_resume.out 'Workspace strategy:'
expect_contains /tmp/campfire_fallback_resume.out 'strategy: in_place'

echo "PASS: Worktree bootstrap verification completed."
