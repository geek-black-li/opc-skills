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
target_parent="${OPCSKILLS_SKILLS_HOME:-$HOME/.agents/skills}"

opc_source="$repository_root/adapters/codex/opc-skills"
opc_target="$target_parent/opc-skills"

if [ ! -f "$opc_source/SKILL.md" ]; then
  echo "Error: Codex entrypoint not found: $opc_source/SKILL.md" >&2
  exit 1
fi

classify_target() {
  source_dir=$1
  target_dir=$2

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

preflight() {
  opc_state=$(classify_target "$opc_source" "$opc_target")
}

refuse_conflicts() {
  if [ "$opc_state" = conflict ]; then
    echo "Error: refusing to modify existing path: $opc_target" >&2
    return 1
  fi
}

print_status() {
  entry_name=$1
  state=$2
  target_dir=$3
  echo "$entry_name: $state ($target_dir)"
}

rollback_created() {
  if [ "$created_opc" -eq 1 ] &&
     [ "$(classify_target "$opc_source" "$opc_target")" = current ]; then
    rm -- "$opc_target"
  fi
}

case "$action" in
  install)
    preflight
    if ! refuse_conflicts; then
      echo "No entrypoints were changed." >&2
      exit 1
    fi

    mkdir -p "$target_parent"
    created_opc=0

    if [ "$opc_state" = absent ]; then
      created_opc=1
      if ! ln -s "$opc_source" "$opc_target"; then
        rollback_created
        echo "Error: installation failed; newly created entrypoints were rolled back." >&2
        exit 1
      fi
    fi

    echo "OPCSkills installed successfully."
    print_status opc-skills current "$opc_target"
    echo "Repository: $repository_root"
    echo 'Restart Codex if needed, then run: $opc-skills 查看仓库状态'
    echo 'Optional completion reminder: bash scripts/configure-codex-reminder.sh install'
    ;;

  status)
    preflight
    print_status opc-skills "$opc_state" "$opc_target"
    if [ "$opc_state" = current ]; then
      exit 0
    fi
    exit 1
    ;;

  uninstall)
    preflight
    if ! refuse_conflicts; then
      echo "No entrypoints were changed." >&2
      exit 1
    fi

    if [ "$opc_state" = current ]; then
      rm -- "$opc_target"
    fi
    echo "OPCSkills Codex entrypoint removed."
    echo "Repository preserved: $repository_root"
    ;;
esac
