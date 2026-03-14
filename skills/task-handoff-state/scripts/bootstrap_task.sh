#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(pwd -P)"
TASK_SLUG=""
USE_WORKTREE=false
WORKTREE_ROOT=""
BRANCH_NAME=""
BASE_REF=""

usage() {
  cat <<'EOF'
Usage:
  bootstrap_task.sh [--root /path/to/workspace] [--slug task-slug] [--worktree] [--worktree-root /path/to/worktrees] [--branch branch-name] [--base-ref git-ref] "task objective"
EOF
}

slugify() {
  local value
  value="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g; s/-\{2,\}/-/g; s/^-//; s/-$//')"
  printf '%s' "${value:-task}"
}

mark_workspace() {
  local task_dir="$1"
  local strategy="$2"
  local root="$3"
  local git_root="$4"
  local branch="$5"

  python3 - "$task_dir/checkpoints.json" "$strategy" "$root" "$git_root" "$branch" <<'PY'
import json
import sys
from pathlib import Path

checkpoint_path = Path(sys.argv[1])
strategy = sys.argv[2]
root = sys.argv[3]
git_root = sys.argv[4]
branch = sys.argv[5]

data = json.loads(checkpoint_path.read_text())
data["workspace"] = {
    "strategy": strategy,
    "root": root,
    "git_root": git_root,
    "branch": branch,
}
checkpoint_path.write_text(json.dumps(data, indent=2) + "\n")
PY

  python3 - "$task_dir/runbook.md" "$strategy" "$root" "$git_root" "$branch" <<'PY'
import sys
from pathlib import Path

runbook_path = Path(sys.argv[1])
strategy = sys.argv[2]
root = sys.argv[3]
git_root = sys.argv[4]
branch = sys.argv[5]

lines = runbook_path.read_text().splitlines()
notes = [
    f"- Workspace strategy: {strategy}",
    f"- Active workspace root: {root}",
]
if git_root:
    notes.append(f"- Git root: {git_root}")
if branch:
    notes.append(f"- Branch: {branch}")

filtered = [
    line for line in lines
    if not line.startswith("- Workspace strategy:")
    and not line.startswith("- Active workspace root:")
    and not line.startswith("- Git root:")
    and not line.startswith("- Branch:")
]

try:
    idx = filtered.index("## Notes")
except ValueError:
    filtered.extend(["", "## Notes"])
    idx = len(filtered) - 1

prefix = filtered[: idx + 1]
suffix = filtered[idx + 1 :]
while suffix and suffix[0] == "":
    suffix = suffix[1:]

updated = prefix + [""] + notes
if suffix:
    updated += [""] + suffix

runbook_path.write_text("\n".join(updated).rstrip() + "\n")
PY
}

POSITIONAL=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --root)
      ROOT_DIR="$2"
      shift 2
      ;;
    --slug)
      TASK_SLUG="$2"
      shift 2
      ;;
    --worktree)
      USE_WORKTREE=true
      shift
      ;;
    --worktree-root)
      WORKTREE_ROOT="$2"
      shift 2
      ;;
    --branch)
      BRANCH_NAME="$2"
      shift 2
      ;;
    --base-ref)
      BASE_REF="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

if [ "${#POSITIONAL[@]}" -lt 1 ]; then
  usage >&2
  exit 1
fi

OBJECTIVE="${POSITIONAL[1]}"
TASK_SLUG="${TASK_SLUG:-$(slugify "$OBJECTIVE")}"
ROOT_DIR="$(cd "$ROOT_DIR" && pwd)"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INIT_SCRIPT="$SCRIPT_DIR/init_task.sh"

if [ ! -x "$INIT_SCRIPT" ]; then
  echo "Missing init_task.sh beside bootstrap_task.sh" >&2
  exit 1
fi

WORKSPACE_ROOT="$ROOT_DIR"
WORKSPACE_STRATEGY="in_place"
GIT_ROOT=""

if $USE_WORKTREE; then
  if git -C "$ROOT_DIR" rev-parse --show-toplevel >/dev/null 2>&1; then
    GIT_ROOT="$(git -C "$ROOT_DIR" rev-parse --show-toplevel)"
    REPO_NAME="$(basename "$GIT_ROOT")"
    WORKTREE_ROOT="${WORKTREE_ROOT:-$(dirname "$GIT_ROOT")/${REPO_NAME}-worktrees}"
    BASE_REF="${BASE_REF:-$(git -C "$GIT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || printf 'HEAD')}"
    BRANCH_NAME="${BRANCH_NAME:-codex/$TASK_SLUG}"
    WORKSPACE_ROOT="$WORKTREE_ROOT/$TASK_SLUG"

    if [ -e "$WORKSPACE_ROOT" ]; then
      echo "Worktree path already exists: $WORKSPACE_ROOT" >&2
      exit 1
    fi

    if git -C "$GIT_ROOT" show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
      echo "Branch already exists: $BRANCH_NAME" >&2
      exit 1
    fi

    mkdir -p "$WORKTREE_ROOT"
    git -C "$GIT_ROOT" worktree add -b "$BRANCH_NAME" "$WORKSPACE_ROOT" "$BASE_REF" >/tmp/campfire_worktree_add.out
    WORKSPACE_STRATEGY="git_worktree"
  else
    echo "Worktree requested but $ROOT_DIR is not a git repo; falling back to in-place task setup."
  fi
fi

"$INIT_SCRIPT" --root "$WORKSPACE_ROOT" --slug "$TASK_SLUG" "$OBJECTIVE" >/tmp/campfire_bootstrap_init.out

mark_workspace "$WORKSPACE_ROOT/.autonomous/$TASK_SLUG" "$WORKSPACE_STRATEGY" "$WORKSPACE_ROOT" "$GIT_ROOT" "$BRANCH_NAME"

echo "Bootstrapped task:"
echo "  slug: $TASK_SLUG"
echo "  workspace: $WORKSPACE_ROOT"
echo "  strategy: $WORKSPACE_STRATEGY"
if [ -n "$GIT_ROOT" ]; then
  echo "  git_root: $GIT_ROOT"
fi
if [ -n "$BRANCH_NAME" ] && [ "$WORKSPACE_STRATEGY" = "git_worktree" ]; then
  echo "  branch: $BRANCH_NAME"
fi
echo
echo "Recommended Codex App prompt:"
echo "  Use \$task-framer, \$course-corrector, \$long-horizon-worker, \$task-evaluator, and \$task-handoff-state to continue .autonomous/$TASK_SLUG/. Keep planning bounded, auto-advance through queued milestones, replenish the queue when policy allows and budget remains, and stop only on the configured run limits or a real blocker."
