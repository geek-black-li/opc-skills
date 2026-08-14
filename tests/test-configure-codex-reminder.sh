#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script_path="$repository_root/scripts/configure-codex-reminder.sh"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local file_path="$1"
  local expected="$2"
  grep -Fq -- "$expected" "$file_path" || fail "$file_path does not contain: $expected"
}

assert_not_contains() {
  local file_path="$1"
  local unexpected="$2"
  if grep -Fq -- "$unexpected" "$file_path"; then
    fail "$file_path unexpectedly contains: $unexpected"
  fi
}

assert_marker_count() {
  local file_path="$1"
  local expected="$2"
  local marker
  local actual
  for marker in '<!-- zx-skills-reminder:start -->' '<!-- zx-skills-reminder:end -->'; do
    actual="$(grep -Fxc -- "$marker" "$file_path" || true)"
    [[ "$actual" == "$expected" ]] || fail "$marker appears $actual times in $file_path, expected $expected"
  done
}

export CODEX_HOME="$test_root/codex"
mkdir -p "$CODEX_HOME"
printf '# Existing global rules\n\n- Keep before.\n<!-- zx-skills-reminder:start -->\n## ZXSkills 沉淀提醒\n- Legacy command: `$zx-skills 总结一下当前链路`\n<!-- zx-skills-reminder:end -->\n- Keep after.\n' > "$CODEX_HOME/AGENTS.md"

"$script_path" install
assert_contains "$CODEX_HOME/AGENTS.md" '# Existing global rules'
assert_contains "$CODEX_HOME/AGENTS.md" '- Keep before.'
assert_contains "$CODEX_HOME/AGENTS.md" '- Keep after.'
assert_marker_count "$CODEX_HOME/AGENTS.md" 1
assert_contains "$CODEX_HOME/AGENTS.md" '$opc-skills 总结一下当前链路'
assert_not_contains "$CODEX_HOME/AGENTS.md" '$zx-skills 总结一下当前链路'

"$script_path" install
assert_marker_count "$CODEX_HOME/AGENTS.md" 1

"$script_path" status

"$script_path" uninstall
assert_contains "$CODEX_HOME/AGENTS.md" '# Existing global rules'
assert_contains "$CODEX_HOME/AGENTS.md" '- Keep before.'
assert_contains "$CODEX_HOME/AGENTS.md" '- Keep after.'
assert_marker_count "$CODEX_HOME/AGENTS.md" 0

printf '# Base rules\n\n- Base before.\n<!-- zx-skills-reminder:start -->\n## ZXSkills 沉淀提醒\n- Legacy command: `$zx-skills 总结一下当前链路`\n<!-- zx-skills-reminder:end -->\n- Base after.\n' > "$CODEX_HOME/AGENTS.md"
printf '# Temporary override\n' > "$CODEX_HOME/AGENTS.override.md"
"$script_path" install
assert_contains "$CODEX_HOME/AGENTS.md" '# Base rules'
assert_contains "$CODEX_HOME/AGENTS.md" '- Base before.'
assert_contains "$CODEX_HOME/AGENTS.md" '- Base after.'
assert_marker_count "$CODEX_HOME/AGENTS.md" 0
assert_contains "$CODEX_HOME/AGENTS.override.md" '# Temporary override'
assert_marker_count "$CODEX_HOME/AGENTS.override.md" 1
assert_contains "$CODEX_HOME/AGENTS.override.md" '$opc-skills 总结一下当前链路'
assert_not_contains "$CODEX_HOME/AGENTS.override.md" '$zx-skills 总结一下当前链路'
"$script_path" uninstall
assert_contains "$CODEX_HOME/AGENTS.override.md" '# Temporary override'
assert_marker_count "$CODEX_HOME/AGENTS.override.md" 0

printf '# Active base rules\n' > "$CODEX_HOME/AGENTS.md"
: > "$CODEX_HOME/AGENTS.override.md"
"$script_path" install
assert_marker_count "$CODEX_HOME/AGENTS.md" 1
assert_marker_count "$CODEX_HOME/AGENTS.override.md" 0
"$script_path" uninstall

printf '<!-- zx-skills-reminder:start -->\n' > "$CODEX_HOME/AGENTS.md"
if "$script_path" install >/dev/null 2>&1; then
  fail "install accepted malformed managed markers"
fi

assert_contains "$repository_root/README.md" 'configure-codex-reminder.sh install'
assert_contains "$repository_root/README.md" '只提醒，不自动执行'

echo "END-OF-SUITE: OPCSkills POSIX reminder tests passed (legacy upgrade, status, uninstall, override migration, malformed markers, README)."
