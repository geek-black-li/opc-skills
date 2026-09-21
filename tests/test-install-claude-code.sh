#!/usr/bin/env bash

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
repository_root=$(CDPATH= cd -- "$script_dir/.." && pwd -P)
script_path="$repository_root/scripts/install-claude-code.sh"
source_dir="$repository_root/adapters/claude-code/opc-skills"
suite_root=$(mktemp -d)
real_ln=$(command -v ln)

cleanup() {
  rm -rf "$suite_root"
}
trap cleanup EXIT HUP INT TERM

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_success() {
  "$@" || fail "expected success: $*"
}

assert_failure() {
  if "$@"; then
    fail "expected failure: $*"
  fi
}

new_case() {
  case_name=$1
  case_root="$suite_root/$case_name"
  case_home="$case_root/home"
  skills_home="$case_root/skills"
  mkdir -p "$case_home"
}

run_installer() {
  output_file=$2
  HOME="$case_home" OPCSKILLS_CLAUDE_SKILLS_HOME="$skills_home" \
    bash "$script_path" "$1" >"$output_file" 2>&1
}

assert_current_link() {
  target=$1
  [ -L "$target" ] || fail "$target is not a symbolic link"
  actual=$(CDPATH= cd -- "$target" && pwd -P)
  expected=$(CDPATH= cd -- "$source_dir" && pwd -P)
  [ "$actual" = "$expected" ] || fail "$target resolves to $actual, expected $expected"
  [ -f "$target/SKILL.md" ] || fail "$target does not expose SKILL.md"
}

assert_absent() {
  target=$1
  [ ! -e "$target" ] && [ ! -L "$target" ] || fail "$target should be absent"
}

assert_status() {
  output_file=$1
  state=$2
  grep -q "^opc-skills: $state " "$output_file" || fail "status did not report $state"
}

run_fresh_lifecycle() {
  new_case fresh
  assert_success run_installer install "$case_root/install.out"
  assert_current_link "$skills_home/opc-skills"
  grep -q '/opc-skills' "$case_root/install.out" || fail "install output lacks Claude invocation"

  raw_link=$(readlink "$skills_home/opc-skills")
  assert_success run_installer install "$case_root/reinstall.out"
  [ "$(readlink "$skills_home/opc-skills")" = "$raw_link" ] || fail "reinstall replaced current link"

  assert_success run_installer status "$case_root/status.out"
  assert_status "$case_root/status.out" current

  assert_success run_installer uninstall "$case_root/uninstall.out"
  assert_absent "$skills_home/opc-skills"
}

run_default_location() {
  new_case default-location
  HOME="$case_home" env -u OPCSKILLS_CLAUDE_SKILLS_HOME \
    bash "$script_path" install >"$case_root/install.out" 2>&1
  assert_current_link "$case_home/.claude/skills/opc-skills"
  HOME="$case_home" env -u OPCSKILLS_CLAUDE_SKILLS_HOME \
    bash "$script_path" uninstall >"$case_root/uninstall.out" 2>&1
  assert_absent "$case_home/.claude/skills/opc-skills"
}

run_absent_status() {
  new_case absent-status
  assert_failure run_installer status "$case_root/status.out"
  assert_status "$case_root/status.out" absent
  [ ! -e "$skills_home" ] || fail "status created the target directory"
}

run_conflicts() {
  for kind in file directory foreign-link broken-link; do
    new_case "conflict-$kind"
    mkdir -p "$skills_home"
    target="$skills_home/opc-skills"
    case "$kind" in
      file) printf 'foreign-file' > "$target" ;;
      directory) mkdir "$target"; printf 'foreign-directory' > "$target/marker" ;;
      foreign-link)
        mkdir -p "$case_root/foreign"
        "$real_ln" -s "$case_root/foreign" "$target"
        ;;
      broken-link) "$real_ln" -s missing-target "$target" ;;
    esac
    before=$(ls -ld "$target")
    assert_failure run_installer install "$case_root/install.out"
    [ "$(ls -ld "$target")" = "$before" ] || fail "$kind conflict changed"
    grep -q 'refusing to modify existing path' "$case_root/install.out" || fail "conflict reason missing"
  done
}

run_fresh_lifecycle
run_default_location
run_absent_status
run_conflicts

echo "PASS: Claude Code installer covers discovery path, lifecycle, idempotency and conflict protection"
