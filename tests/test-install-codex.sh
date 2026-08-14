#!/usr/bin/env bash

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
repository_root=$(CDPATH= cd -- "$script_dir/.." && pwd -P)
script_path="$repository_root/scripts/install-codex.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_current_link() {
  entry_name=$1
  expected_source=$2
  target="$OPCSKILLS_SKILLS_HOME/$entry_name"

  [ -L "$target" ] || fail "$target is not a symbolic link"
  actual_source=$(CDPATH= cd -- "$target" && pwd -P)
  [ "$actual_source" = "$expected_source" ] ||
    fail "$target resolves to $actual_source, expected $expected_source"
}

assert_absent() {
  target=$1
  [ ! -e "$target" ] && [ ! -L "$target" ] || fail "$target should be absent"
}

run_fresh_install_case() {
  test_root=$(mktemp -d)
  HOME="$test_root/home"
  OPCSKILLS_SKILLS_HOME="$test_root/skills"
  export HOME OPCSKILLS_SKILLS_HOME
  mkdir -p "$HOME"
  trap 'rm -rf "$test_root"' EXIT HUP INT TERM

  "$script_path" install
  assert_current_link opc-skills "$repository_root/adapters/codex/opc-skills"
  assert_current_link zx-skills "$repository_root/adapters/codex/zx-skills"
  status_output=$("$script_path" status)
  [ "$(printf '%s\n' "$status_output" | wc -l | tr -d ' ')" -eq 2 ] ||
    fail "status should print exactly one line per entry"
  printf '%s\n' "$status_output" | grep -q '^opc-skills: current ' ||
    fail "status did not report opc-skills as current"
  printf '%s\n' "$status_output" | grep -q '^zx-skills: current ' ||
    fail "status did not report zx-skills as current"
  "$script_path" install
  "$script_path" uninstall
  assert_absent "$OPCSKILLS_SKILLS_HOME/opc-skills"
  assert_absent "$OPCSKILLS_SKILLS_HOME/zx-skills"

  rm -rf "$test_root"
  trap - EXIT HUP INT TERM
}

run_legacy_upgrade_case() {
  test_root=$(mktemp -d)
  HOME="$test_root/home"
  OPCSKILLS_SKILLS_HOME="$test_root/skills"
  export HOME OPCSKILLS_SKILLS_HOME
  mkdir -p "$HOME"
  trap 'rm -rf "$test_root"' EXIT HUP INT TERM
  mkdir -p "$OPCSKILLS_SKILLS_HOME"
  ln -s "$repository_root/adapters/codex/zx-skills" "$OPCSKILLS_SKILLS_HOME/zx-skills"

  "$script_path" install
  assert_current_link opc-skills "$repository_root/adapters/codex/opc-skills"
  assert_current_link zx-skills "$repository_root/adapters/codex/zx-skills"

  rm -rf "$test_root"
  trap - EXIT HUP INT TERM
}

run_conflict_case() {
  test_root=$(mktemp -d)
  HOME="$test_root/home"
  OPCSKILLS_SKILLS_HOME="$test_root/skills"
  export HOME OPCSKILLS_SKILLS_HOME
  mkdir -p "$HOME"
  trap 'rm -rf "$test_root"' EXIT HUP INT TERM
  mkdir -p "$OPCSKILLS_SKILLS_HOME"
  printf '%s\n' 'user-owned content' > "$OPCSKILLS_SKILLS_HOME/opc-skills"

  if "$script_path" install >"$test_root/install.out" 2>&1; then
    fail "install should reject a foreign opc-skills path"
  fi
  [ "$(cat "$OPCSKILLS_SKILLS_HOME/opc-skills")" = 'user-owned content' ] ||
    fail "install changed the foreign opc-skills file"
  assert_absent "$OPCSKILLS_SKILLS_HOME/zx-skills"

  ln -s "$repository_root/adapters/codex/zx-skills" "$OPCSKILLS_SKILLS_HOME/zx-skills"
  if "$script_path" uninstall >"$test_root/uninstall.out" 2>&1; then
    fail "uninstall should reject a foreign opc-skills path"
  fi
  [ "$(cat "$OPCSKILLS_SKILLS_HOME/opc-skills")" = 'user-owned content' ] ||
    fail "uninstall changed the foreign opc-skills file"
  assert_current_link zx-skills "$repository_root/adapters/codex/zx-skills"

  rm -rf "$test_root"
  trap - EXIT HUP INT TERM
}

run_fresh_install_case
run_legacy_upgrade_case
run_conflict_case

echo "PASS: POSIX Codex installer manages both entrypoints safely"
