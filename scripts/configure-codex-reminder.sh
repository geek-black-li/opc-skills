#!/usr/bin/env bash

set -euo pipefail

action="${1:-install}"
case "$action" in
  install|status|uninstall) ;;
  *)
    echo "Usage: $0 [install|status|uninstall]" >&2
    exit 2
    ;;
esac

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
template_path="$repository_root/templates/codex-agents-reminder.md"
codex_home="${CODEX_HOME:-$HOME/.codex}"
agents_file="$codex_home/AGENTS.md"
override_file="$codex_home/AGENTS.override.md"
start_marker='<!-- zx-skills-reminder:start -->'
end_marker='<!-- zx-skills-reminder:end -->'

if [[ ! -f "$template_path" ]]; then
  echo "Error: reminder template not found: $template_path" >&2
  exit 1
fi

marker_count() {
  local file_path="$1"
  local marker="$2"
  if [[ ! -f "$file_path" ]]; then
    printf '0\n'
    return
  fi
  awk -v marker="$marker" '$0 == marker { count += 1 } END { print count + 0 }' "$file_path"
}

validate_markers() {
  local file_path="$1"
  local start_count end_count
  start_count="$(marker_count "$file_path" "$start_marker")"
  end_count="$(marker_count "$file_path" "$end_marker")"
  if [[ "$start_count" != "$end_count" || "$start_count" -gt 1 ]]; then
    echo "Error: malformed ZXSkills reminder markers in $file_path; fix them manually before retrying." >&2
    exit 1
  fi
}

has_managed_block() {
  [[ "$(marker_count "$1" "$start_marker")" == "1" ]]
}

remove_managed_block() {
  local file_path="$1"
  local temp_file
  [[ -f "$file_path" ]] || return
  has_managed_block "$file_path" || return 0
  temp_file="$(mktemp "$codex_home/.zx-skills-agents.XXXXXX")"
  awk -v start="$start_marker" -v end="$end_marker" '
    $0 == start { skipping = 1; pending_blank = 0; next }
    $0 == end { skipping = 0; next }
    skipping { next }
    $0 == "" { pending_blank += 1; next }
    {
      while (pending_blank > 0) {
        print ""
        pending_blank -= 1
      }
      print
    }
  ' "$file_path" > "$temp_file"
  mv "$temp_file" "$file_path"
}

append_template() {
  local file_path="$1"
  if [[ -s "$file_path" ]]; then
    printf '\n\n' >> "$file_path"
  fi
  sed -n 'p' "$template_path" >> "$file_path"
}

active_file="$agents_file"
if [[ -s "$override_file" ]]; then
  active_file="$override_file"
fi

validate_markers "$agents_file"
validate_markers "$override_file"

case "$action" in
  install)
    mkdir -p "$codex_home"

    if [[ "$active_file" == "$override_file" ]] && has_managed_block "$agents_file"; then
      remove_managed_block "$agents_file"
    elif [[ "$active_file" == "$agents_file" ]] && has_managed_block "$override_file"; then
      remove_managed_block "$override_file"
    fi

    touch "$active_file"
    remove_managed_block "$active_file"
    append_template "$active_file"

    echo "ZXSkills completion reminder configured."
    echo "Global Codex instructions: $active_file"
    echo "Mode: remind only; ZXSkills will not run or modify files automatically."
    echo "Start a new Codex task to load the updated global instructions."
    ;;

  status)
    if has_managed_block "$active_file"; then
      echo "ZXSkills completion reminder is configured."
      echo "Global Codex instructions: $active_file"
      exit 0
    fi

    inactive_file="$override_file"
    if [[ "$active_file" == "$override_file" ]]; then
      inactive_file="$agents_file"
    fi
    if has_managed_block "$inactive_file"; then
      echo "ZXSkills reminder exists in an inactive global instructions file: $inactive_file" >&2
      echo "Run '$0 install' to move it to: $active_file" >&2
      exit 1
    fi

    echo "ZXSkills completion reminder is not configured."
    echo "Expected global Codex instructions: $active_file"
    exit 1
    ;;

  uninstall)
    removed=false
    if has_managed_block "$agents_file"; then
      remove_managed_block "$agents_file"
      removed=true
    fi
    if has_managed_block "$override_file"; then
      remove_managed_block "$override_file"
      removed=true
    fi

    if [[ "$removed" == "true" ]]; then
      echo "ZXSkills completion reminder removed."
      echo "Other global Codex instructions were preserved."
    else
      echo "ZXSkills completion reminder is not configured; nothing changed."
    fi
    ;;
esac
