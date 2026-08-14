#!/usr/bin/env bash

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
repository_root=$(CDPATH= cd -- "$script_dir/.." && pwd -P)
script_path="$repository_root/scripts/install-codex.sh"
opc_source="$repository_root/adapters/codex/opc-skills"
original_home=$HOME
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

new_case() {
  case_name=$1
  case_root="$suite_root/$case_name"
  case_home="$case_root/home"
  skills_home="$case_root/skills"
  mkdir -p "$case_home"
}

run_installer_quiet() {
  output_file=$2
  HOME="$case_home" OPCSKILLS_SKILLS_HOME="$skills_home" \
    "$script_path" "$1" >"$output_file" 2>&1
}

run_fallback_installer() {
  env -u OPCSKILLS_SKILLS_HOME HOME="$case_home" "$script_path" "$1"
}

assert_success() {
  "$@" || fail "expected success: $*"
}

assert_failure() {
  if "$@"; then
    fail "expected failure: $*"
  fi
}

assert_current_link_at() {
  target=$1
  expected_source=$2
  [ -L "$target" ] || fail "$target is not a symbolic link"
  actual_source=$(CDPATH= cd -- "$target" && pwd -P)
  [ "$actual_source" = "$expected_source" ] ||
    fail "$target resolves to $actual_source, expected $expected_source"
}

assert_absent() {
  target=$1
  [ ! -e "$target" ] && [ ! -L "$target" ] || fail "$target should be absent"
}

assert_status_line() {
  output_file=$1
  entry_name=$2
  expected_state=$3
  grep -q "^$entry_name: $expected_state " "$output_file" ||
    fail "status did not report $entry_name as $expected_state"
}

relative_path() {
  python3 - "$1" "$2" <<'PY'
import os
import sys

print(os.path.relpath(sys.argv[2], sys.argv[1]))
PY
}

create_current_link() {
  target=$1
  mode=${2:-absolute}
  mkdir -p "$(dirname -- "$target")"
  if [ "$mode" = relative ]; then
    physical_parent=$(CDPATH= cd -- "$(dirname -- "$target")" && pwd -P)
    link_value=$(relative_path "$physical_parent" "$opc_source")
  else
    link_value=$opc_source
  fi
  "$real_ln" -s "$link_value" "$target"
}

run_fresh_lifecycle_case() {
  new_case fresh
  assert_success run_installer_quiet install "$case_root/install.out"
  assert_current_link_at "$skills_home/opc-skills" "$opc_source"
  assert_absent "$skills_home/zx-skills"

  assert_success run_installer_quiet status "$case_root/status.out"
  assert_status_line "$case_root/status.out" opc-skills current
  [ "$(wc -l < "$case_root/status.out" | tr -d ' ')" -eq 1 ] ||
    fail "status should print exactly one line"

  opc_raw=$(readlink "$skills_home/opc-skills")
  assert_success run_installer_quiet install "$case_root/reinstall.out"
  [ "$(readlink "$skills_home/opc-skills")" = "$opc_raw" ] || fail "reinstall replaced opc-skills"

  assert_success run_installer_quiet uninstall "$case_root/uninstall.out"
  assert_absent "$skills_home/opc-skills"
  assert_absent "$skills_home/zx-skills"
  grep -qx 'OPCSkills Codex entrypoint removed\.' "$case_root/uninstall.out" ||
    fail "uninstall did not use the singular removal message"
}

run_ignored_legacy_name_case() {
  new_case ignored-legacy-name
  mkdir -p "$skills_home"
  printf 'foreign\n' > "$skills_home/zx-skills"
  assert_success run_installer_quiet install "$case_root/install.out"
  assert_current_link_at "$skills_home/opc-skills" "$opc_source"
  [ "$(cat "$skills_home/zx-skills")" = foreign ] || fail "installer modified unrelated zx-skills path"
}

run_status_matrix() {
  new_case status-absent
  assert_failure run_installer_quiet status "$case_root/status.out"
  assert_status_line "$case_root/status.out" opc-skills absent
  [ "$(wc -l < "$case_root/status.out" | tr -d ' ')" -eq 1 ] ||
    fail "absent status should print exactly one line"
  [ ! -e "$skills_home" ] || fail "absent status created the target parent"

  new_case status-current
  create_current_link "$skills_home/opc-skills" relative
  opc_raw=$(readlink "$skills_home/opc-skills")
  assert_success run_installer_quiet status "$case_root/status.out"
  assert_status_line "$case_root/status.out" opc-skills current
  [ "$(readlink "$skills_home/opc-skills")" = "$opc_raw" ] || fail "status replaced opc-skills"
}

run_fallback_case() {
  new_case fallback
  fallback_skills="$case_home/.agents/skills"
  assert_success run_fallback_installer install >"$case_root/install.out" 2>&1
  assert_current_link_at "$fallback_skills/opc-skills" "$opc_source"
  assert_absent "$fallback_skills/zx-skills"
  [ "$HOME" = "$original_home" ] || fail "test changed parent HOME"
  assert_success run_fallback_installer uninstall >"$case_root/uninstall.out" 2>&1
  assert_absent "$fallback_skills/opc-skills"
}

run_relative_idempotency_case() {
  new_case relative-idempotency
  create_current_link "$skills_home/opc-skills" relative
  opc_raw=$(readlink "$skills_home/opc-skills")

  assert_success run_installer_quiet install "$case_root/install-1.out"
  assert_success run_installer_quiet install "$case_root/install-2.out"
  [ "$(readlink "$skills_home/opc-skills")" = "$opc_raw" ] || fail "relative opc-skills was replaced"
}

create_conflict() {
  conflict_kind=$1
  conflict_path="$skills_home/opc-skills"
  conflict_fixture="$case_root/conflict-fixture"
  mkdir -p "$skills_home"

  case "$conflict_kind" in
    foreign-link)
      mkdir -p "$conflict_fixture/foreign-target"
      printf '%s' 'foreign-link-content' > "$conflict_fixture/foreign-target/marker.txt"
      conflict_expected="$conflict_fixture/foreign-target"
      "$real_ln" -s "$conflict_expected" "$conflict_path"
      ;;
    broken-link)
      conflict_expected='missing-target'
      "$real_ln" -s "$conflict_expected" "$conflict_path"
      ;;
    ordinary-directory)
      mkdir -p "$conflict_path"
      conflict_expected='ordinary-directory-content'
      printf '%s' "$conflict_expected" > "$conflict_path/marker.txt"
      ;;
    repository-directory)
      mkdir -p "$conflict_path/.git"
      conflict_expected='repository-owned-content'
      printf '%s' "$conflict_expected" > "$conflict_path/.git/config"
      ;;
    business-skill-directory)
      mkdir -p "$conflict_path"
      conflict_expected='business-skill-owned-content'
      printf '%s' "$conflict_expected" > "$conflict_path/SKILL.md"
      ;;
    *) fail "unknown conflict kind: $conflict_kind" ;;
  esac
}

assert_conflict_intact() {
  conflict_kind=$1
  conflict_path="$skills_home/opc-skills"
  case "$conflict_kind" in
    foreign-link|broken-link)
      [ -L "$conflict_path" ] || fail "$conflict_kind link was removed"
      [ "$(readlink "$conflict_path")" = "$conflict_expected" ] || fail "$conflict_kind target changed"
      if [ "$conflict_kind" = foreign-link ]; then
        [ "$(cat "$conflict_expected/marker.txt")" = 'foreign-link-content' ] || fail "foreign link content changed"
      fi
      ;;
    ordinary-directory)
      [ "$(cat "$conflict_path/marker.txt")" = "$conflict_expected" ] || fail "ordinary directory changed"
      ;;
    repository-directory)
      [ "$(cat "$conflict_path/.git/config")" = "$conflict_expected" ] || fail "repository directory changed"
      ;;
    business-skill-directory)
      [ "$(cat "$conflict_path/SKILL.md")" = "$conflict_expected" ] || fail "business Skill directory changed"
      ;;
  esac
}

run_conflict_matrix() {
  for conflict_kind in foreign-link broken-link ordinary-directory repository-directory business-skill-directory; do
    new_case "conflict-$conflict_kind"
    create_conflict "$conflict_kind"

    assert_failure run_installer_quiet status "$case_root/status.out"
    assert_status_line "$case_root/status.out" opc-skills conflict
    [ "$(wc -l < "$case_root/status.out" | tr -d ' ')" -eq 1 ] ||
      fail "conflict status should print exactly one line"
    assert_conflict_intact "$conflict_kind"

    assert_failure run_installer_quiet install "$case_root/install.out"
    assert_conflict_intact "$conflict_kind"

    assert_failure run_installer_quiet uninstall "$case_root/uninstall.out"
    assert_conflict_intact "$conflict_kind"
  done
}

write_fault_ln() {
  fault_bin="$case_root/fault-bin"
  mkdir -p "$fault_bin"
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -eu' \
    '"$OPCSKILLS_REAL_LN" "$@"' \
    'echo "injected link failure" >&2' \
    'exit 23' > "$fault_bin/ln"
  chmod +x "$fault_bin/ln"
}

run_fault_installer() {
  output_file=$1
  HOME="$case_home" \
    OPCSKILLS_SKILLS_HOME="$skills_home" \
    OPCSKILLS_REAL_LN="$real_ln" \
    PATH="$fault_bin:$PATH" \
    "$script_path" install >"$output_file" 2>&1
}

run_rollback_case() {
  new_case rollback-opc
  write_fault_ln
  assert_failure run_fault_installer "$case_root/install.out"
  grep -q 'newly created entrypoints were rolled back' "$case_root/install.out" || fail "rollback message missing"
  assert_absent "$skills_home/opc-skills"
}

run_fresh_lifecycle_case
run_ignored_legacy_name_case
run_status_matrix
run_fallback_case
run_relative_idempotency_case
run_conflict_matrix
run_rollback_case

[ "$HOME" = "$original_home" ] || fail "test changed parent HOME"
echo "PASS: POSIX Codex installer covers one owned entrypoint, conflicts, fallback, idempotency, and rollback"
