#!/usr/bin/env bash

set -eu

action="${1:-install}"
case "$action" in
  install|status|uninstall) ;;
  *)
    echo "Usage: bash scripts/install-claude-code.sh [install|status|uninstall]" >&2
    exit 2
    ;;
esac

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
repository_root=$(CDPATH= cd -- "$script_dir/.." && pwd -P)
target_parent="${OPCSKILLS_CLAUDE_SKILLS_HOME:-$HOME/.claude/skills}"
source_dir="$repository_root/adapters/claude-code/opc-skills"
target_dir="$target_parent/opc-skills"

if [ ! -f "$source_dir/SKILL.md" ]; then
  echo "Error: Claude Code entrypoint not found: $source_dir/SKILL.md" >&2
  exit 1
fi

classify_target() {
  if [ ! -e "$target_dir" ] && [ ! -L "$target_dir" ]; then
    echo absent
    return
  fi
  if [ ! -L "$target_dir" ]; then
    echo conflict
    return
  fi

  link_value=$(readlink "$target_dir")
  case "$link_value" in
    /*) candidate="$link_value" ;;
    *) candidate="$(dirname -- "$target_dir")/$link_value" ;;
  esac
  if [ -d "$candidate" ] &&
     [ "$(CDPATH= cd -- "$candidate" && pwd -P)" = "$source_dir" ]; then
    echo current
  else
    echo conflict
  fi
}

state=$(classify_target)

case "$action" in
  status)
    echo "opc-skills: $state ($target_dir)"
    [ "$state" = current ]
    ;;

  install)
    if [ "$state" = conflict ]; then
      echo "Error: refusing to modify existing path: $target_dir" >&2
      echo "No entrypoints were changed." >&2
      exit 1
    fi
    mkdir -p "$target_parent"
    if [ "$state" = absent ]; then
      if ! ln -s "$source_dir" "$target_dir"; then
        if [ -L "$target_dir" ] && [ "$(classify_target)" = current ]; then
          rm -- "$target_dir"
        fi
        echo "Error: installation failed; newly created entrypoint was rolled back." >&2
        exit 1
      fi
    fi
    echo "OPCSkills Claude Code entrypoint installed successfully."
    echo "opc-skills: current ($target_dir)"
    echo "Repository: $repository_root"
    echo "Restart Claude Code if this top-level skill is new, then run: /opc-skills 查看仓库状态"
    ;;

  uninstall)
    if [ "$state" = conflict ]; then
      echo "Error: refusing to modify existing path: $target_dir" >&2
      echo "No entrypoints were changed." >&2
      exit 1
    fi
    if [ "$state" = current ]; then
      rm -- "$target_dir"
    fi
    echo "OPCSkills Claude Code entrypoint removed."
    echo "Repository preserved: $repository_root"
    ;;
esac
