#!/usr/bin/env bash

set -eu

action="${1:-install}"
case "$action" in
  install|status|uninstall) ;;
  *)
    echo "Usage: bash scripts/install-codex.sh [install|status|uninstall]" >&2
    exit 2
    ;;
esac

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
repository_root=$(CDPATH= cd -- "$script_dir/.." && pwd -P)
source_dir="$repository_root/adapters/codex/zx-skills"
target_parent="$HOME/.agents/skills"
target_dir="$target_parent/zx-skills"

if [ ! -f "$source_dir/SKILL.md" ]; then
  echo "Error: Codex entrypoint not found: $source_dir/SKILL.md" >&2
  exit 1
fi

resolve_existing_target() {
  if [ ! -L "$target_dir" ]; then
    return 1
  fi

  link_value=$(readlink "$target_dir")
  case "$link_value" in
    /*) candidate="$link_value" ;;
    *) candidate="$target_parent/$link_value" ;;
  esac

  if [ ! -d "$candidate" ]; then
    return 1
  fi

  (CDPATH= cd -- "$candidate" && pwd -P)
}

is_current_install() {
  [ -L "$target_dir" ] || return 1
  installed_source=$(resolve_existing_target) || return 1
  [ "$installed_source" = "$source_dir" ]
}

case "$action" in
  install)
    mkdir -p "$target_parent"

    if is_current_install; then
      echo "ZXSkills is already installed."
      echo "Codex entrypoint: $target_dir"
      echo "Repository: $repository_root"
      exit 0
    fi

    if [ -e "$target_dir" ] || [ -L "$target_dir" ]; then
      echo "Error: refusing to overwrite existing path: $target_dir" >&2
      echo "Move or remove that path manually, then run this installer again." >&2
      exit 1
    fi

    ln -s "$source_dir" "$target_dir"
    echo "ZXSkills installed successfully."
    echo "Codex entrypoint: $target_dir"
    echo "Repository: $repository_root"
    echo 'Restart Codex if needed, then run: $zx-skills 查看仓库状态'
    ;;

  status)
    if is_current_install; then
      echo "ZXSkills is installed."
      echo "Codex entrypoint: $target_dir"
      echo "Repository: $repository_root"
      exit 0
    fi

    if [ -e "$target_dir" ] || [ -L "$target_dir" ]; then
      echo "ZXSkills is not installed from this repository."
      echo "Another path already exists at: $target_dir"
      exit 1
    fi

    echo "ZXSkills is not installed."
    echo "Expected entrypoint: $target_dir"
    exit 1
    ;;

  uninstall)
    if is_current_install; then
      rm "$target_dir"
      echo "ZXSkills Codex entrypoint removed."
      echo "Repository preserved: $repository_root"
      exit 0
    fi

    if [ -e "$target_dir" ] || [ -L "$target_dir" ]; then
      echo "Error: refusing to remove a path not installed from this repository: $target_dir" >&2
      exit 1
    fi

    echo "ZXSkills is not installed; nothing changed."
    ;;
esac
