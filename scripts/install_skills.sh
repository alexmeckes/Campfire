#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
SKILLS_DIR="$ROOT_DIR/skills"

install_skill() {
  local name="$1"
  local source_dir="$SKILLS_DIR/$name"
  local target_dir="$CODEX_HOME_DIR/skills/$name"

  if [ ! -d "$source_dir" ]; then
    echo "Missing skill source: $source_dir" >&2
    exit 1
  fi

  mkdir -p "$CODEX_HOME_DIR/skills"

  if [ -e "$target_dir" ] || [ -L "$target_dir" ]; then
    if [ -L "$target_dir" ] && [ "$(readlink "$target_dir")" = "$source_dir" ]; then
      echo "Skill already linked: $name"
      return
    fi

    local backup_dir="${target_dir}.backup.$(date +%Y%m%d%H%M%S)"
    mv "$target_dir" "$backup_dir"
    echo "Backed up existing $name skill to $backup_dir"
  fi

  ln -s "$source_dir" "$target_dir"
  echo "Installed $name:"
  echo "  $target_dir -> $source_dir"
}

install_skill "long-horizon-worker"
install_skill "task-framer"
install_skill "task-handoff-state"
install_skill "course-corrector"
install_skill "task-evaluator"

echo
echo "Restart Codex App so the skill list refreshes."
