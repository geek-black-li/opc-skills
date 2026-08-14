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
zx_source="$repository_root/adapters/codex/zx-skills"
opc_target="$target_parent/opc-skills"
zx_target="$target_parent/zx-skills"

for source_dir in "$opc_source" "$zx_source"; do
  if [ ! -f "$source_dir/SKILL.md" ]; then
    echo "Error: Codex entrypoint not found: $source_dir/SKILL.md" >&2
    exit 1
  fi
done

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
  zx_state=$(classify_target "$zx_source" "$zx_target")
}

refuse_conflicts() {
  found_conflict=0
  if [ "$opc_state" = conflict ]; then
    echo "Error: refusing to modify existing path: $opc_target" >&2
    found_conflict=1
  fi
  if [ "$zx_state" = conflict ]; then
    echo "Error: refusing to modify existing path: $zx_target" >&2
    found_conflict=1
  fi
  [ "$found_conflict" -eq 0 ]
}

print_status() {
  entry_name=$1
  state=$2
  target_dir=$3
  echo "$entry_name: $state ($target_dir)"
}

rollback_created() {
  if [ "$created_zx" -eq 1 ] &&
     [ "$(classify_target "$zx_source" "$zx_target")" = current ]; then
    rm -- "$zx_target"
  fi
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
    created_zx=0

    if [ "$opc_state" = absent ]; then
      if ! ln -s "$opc_source" "$opc_target"; then
        rollback_created
        echo "Error: installation failed; newly created entrypoints were rolled back." >&2
        exit 1
      fi
      created_opc=1
    fi

    if [ "$zx_state" = absent ]; then
      if ! ln -s "$zx_source" "$zx_target"; then
        rollback_created
        echo "Error: installation failed; newly created entrypoints were rolled back." >&2
        exit 1
      fi
      created_zx=1
    fi

    echo "OPCSkills installed successfully."
    print_status opc-skills current "$opc_target"
    print_status zx-skills current "$zx_target"
    echo "Repository: $repository_root"
    echo 'Restart Codex if needed, then run: $opc-skills 查看仓库状态'
    echo 'Optional completion reminder: bash scripts/configure-codex-reminder.sh install'
    ;;

  status)
    preflight
    print_status opc-skills "$opc_state" "$opc_target"
    print_status zx-skills "$zx_state" "$zx_target"
    if [ "$opc_state" = current ] && [ "$zx_state" = current ]; then
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
    if [ "$zx_state" = current ]; then
      rm -- "$zx_target"
    fi
    echo "OPCSkills Codex entrypoints removed."
    echo "Repository preserved: $repository_root"
    ;;
esac
