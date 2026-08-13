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

export CODEX_HOME="$test_root/codex"
mkdir -p "$CODEX_HOME"
printf '# Existing global rules\n\n- Keep this line.\n' > "$CODEX_HOME/AGENTS.md"

"$script_path" install
assert_contains "$CODEX_HOME/AGENTS.md" '# Existing global rules'
assert_contains "$CODEX_HOME/AGENTS.md" '<!-- zx-skills-reminder:start -->'
assert_contains "$CODEX_HOME/AGENTS.md" '$zx-skills 总结一下当前链路'

"$script_path" install
start_count="$(grep -Fxc '<!-- zx-skills-reminder:start -->' "$CODEX_HOME/AGENTS.md")"
[[ "$start_count" == "1" ]] || fail "install is not idempotent"

"$script_path" status

"$script_path" uninstall
assert_contains "$CODEX_HOME/AGENTS.md" '# Existing global rules'
assert_contains "$CODEX_HOME/AGENTS.md" '- Keep this line.'
if grep -Fq '<!-- zx-skills-reminder:start -->' "$CODEX_HOME/AGENTS.md"; then
  fail "uninstall left the managed block behind"
fi

printf '# Base rules\n' > "$CODEX_HOME/AGENTS.md"
printf '# Temporary override\n' > "$CODEX_HOME/AGENTS.override.md"
"$script_path" install
assert_contains "$CODEX_HOME/AGENTS.override.md" '<!-- zx-skills-reminder:start -->'
if grep -Fq -- '<!-- zx-skills-reminder:start -->' "$CODEX_HOME/AGENTS.md"; then
  fail "install wrote the reminder to inactive AGENTS.md"
fi
"$script_path" uninstall
assert_contains "$CODEX_HOME/AGENTS.override.md" '# Temporary override'

printf '# Active base rules\n' > "$CODEX_HOME/AGENTS.md"
: > "$CODEX_HOME/AGENTS.override.md"
"$script_path" install
assert_contains "$CODEX_HOME/AGENTS.md" '<!-- zx-skills-reminder:start -->'
if grep -Fq -- '<!-- zx-skills-reminder:start -->' "$CODEX_HOME/AGENTS.override.md"; then
  fail "install made an empty override active and hid AGENTS.md"
fi
"$script_path" uninstall

printf '<!-- zx-skills-reminder:start -->\n' > "$CODEX_HOME/AGENTS.md"
if "$script_path" install >/dev/null 2>&1; then
  fail "install accepted malformed managed markers"
fi

assert_contains "$repository_root/README.md" 'configure-codex-reminder.sh install'
assert_contains "$repository_root/README.md" '只提醒，不自动执行'

echo "POSIX reminder configuration tests passed."
