#!/usr/bin/env bash

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
repository_root=$(CDPATH= cd -- "$script_dir/.." && pwd -P)
script_path="$repository_root/scripts/install-codex.sh"
opc_source="$repository_root/adapters/codex/opc-skills"
zx_source="$repository_root/adapters/codex/zx-skills"
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

run_installer() {
  HOME="$case_home" OPCSKILLS_SKILLS_HOME="$skills_home" \
    "$script_path" "$1"
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

assert_two_status_lines() {
  output_file=$1
  [ "$(wc -l < "$output_file" | tr -d ' ')" -eq 2 ] ||
    fail "status should print exactly one line per entry"
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
  source=$2
  mode=${3:-absolute}
  mkdir -p "$(dirname -- "$target")"
  if [ "$mode" = relative ]; then
    physical_parent=$(CDPATH= cd -- "$(dirname -- "$target")" && pwd -P)
    link_value=$(relative_path "$physical_parent" "$source")
  else
    link_value=$source
  fi
  "$real_ln" -s "$link_value" "$target"
}

run_fresh_lifecycle_case() {
  new_case fresh
  assert_success run_installer_quiet install "$case_root/install.out"
  assert_current_link_at "$skills_home/opc-skills" "$opc_source"
  assert_current_link_at "$skills_home/zx-skills" "$zx_source"

  assert_success run_installer_quiet status "$case_root/status.out"
  assert_two_status_lines "$case_root/status.out"
  assert_status_line "$case_root/status.out" opc-skills current
  assert_status_line "$case_root/status.out" zx-skills current

  opc_raw=$(readlink "$skills_home/opc-skills")
  zx_raw=$(readlink "$skills_home/zx-skills")
  assert_success run_installer_quiet install "$case_root/reinstall.out"
  [ "$(readlink "$skills_home/opc-skills")" = "$opc_raw" ] || fail "reinstall replaced opc-skills"
  [ "$(readlink "$skills_home/zx-skills")" = "$zx_raw" ] || fail "reinstall replaced zx-skills"

  assert_success run_installer_quiet uninstall "$case_root/uninstall.out"
  assert_absent "$skills_home/opc-skills"
  assert_absent "$skills_home/zx-skills"
}

run_legacy_upgrade_case() {
  new_case legacy
  create_current_link "$skills_home/zx-skills" "$zx_source"
  legacy_raw=$(readlink "$skills_home/zx-skills")

  assert_success run_installer_quiet install "$case_root/install.out"
  assert_current_link_at "$skills_home/opc-skills" "$opc_source"
  assert_current_link_at "$skills_home/zx-skills" "$zx_source"
  [ "$(readlink "$skills_home/zx-skills")" = "$legacy_raw" ] || fail "legacy alias was replaced"
}

run_status_matrix() {
  new_case status-absent
  assert_failure run_installer_quiet status "$case_root/status.out"
  assert_two_status_lines "$case_root/status.out"
  assert_status_line "$case_root/status.out" opc-skills absent
  assert_status_line "$case_root/status.out" zx-skills absent
  [ ! -e "$skills_home" ] || fail "absent status created the target parent"

  new_case status-partial
  create_current_link "$skills_home/opc-skills" "$opc_source" relative
  partial_raw=$(readlink "$skills_home/opc-skills")
  assert_failure run_installer_quiet status "$case_root/status.out"
  assert_two_status_lines "$case_root/status.out"
  assert_status_line "$case_root/status.out" opc-skills current
  assert_status_line "$case_root/status.out" zx-skills absent
  [ "$(readlink "$skills_home/opc-skills")" = "$partial_raw" ] || fail "partial status replaced opc-skills"
  assert_absent "$skills_home/zx-skills"
}

run_fallback_case() {
  new_case fallback
  fallback_skills="$case_home/.agents/skills"
  assert_success run_fallback_installer install >"$case_root/install.out" 2>&1
  assert_current_link_at "$fallback_skills/opc-skills" "$opc_source"
  assert_current_link_at "$fallback_skills/zx-skills" "$zx_source"
  [ "$HOME" = "$original_home" ] || fail "test changed parent HOME"
  assert_success run_fallback_installer uninstall >"$case_root/uninstall.out" 2>&1
  assert_absent "$fallback_skills/opc-skills"
  assert_absent "$fallback_skills/zx-skills"
}

run_relative_idempotency_case() {
  new_case relative-idempotency
  create_current_link "$skills_home/opc-skills" "$opc_source" relative
  create_current_link "$skills_home/zx-skills" "$zx_source" relative
  opc_raw=$(readlink "$skills_home/opc-skills")
  zx_raw=$(readlink "$skills_home/zx-skills")

  assert_success run_installer_quiet install "$case_root/install-1.out"
  assert_success run_installer_quiet install "$case_root/install-2.out"
  [ "$(readlink "$skills_home/opc-skills")" = "$opc_raw" ] || fail "relative opc-skills was replaced"
  [ "$(readlink "$skills_home/zx-skills")" = "$zx_raw" ] || fail "relative zx-skills was replaced"
}

create_conflict() {
  conflict_kind=$1
  conflict_path=$2
  conflict_fixture="$case_root/conflict-fixture"

  case "$conflict_kind" in
    foreign-link)
      mkdir -p "$conflict_fixture/foreign-target"
      printf '%s' 'foreign-link-content' > "$conflict_fixture/foreign-target/marker.txt"
      conflict_expected="$conflict_fixture/foreign-target"
      "$real_ln" -s "$conflict_expected" "$conflict_path"
      ;;
    broken-link)
      conflict_expected="missing-target-$conflict_entry"
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
  conflict_path=$2
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
    for conflict_entry in opc-skills zx-skills; do
      new_case "conflict-$conflict_kind-$conflict_entry"
      mkdir -p "$skills_home"
      conflict_path="$skills_home/$conflict_entry"
      if [ "$conflict_entry" = opc-skills ]; then
        other_entry=zx-skills
        other_source=$zx_source
      else
        other_entry=opc-skills
        other_source=$opc_source
      fi
      other_path="$skills_home/$other_entry"
      create_conflict "$conflict_kind" "$conflict_path"

      assert_failure run_installer_quiet status "$case_root/status.out"
      assert_two_status_lines "$case_root/status.out"
      assert_status_line "$case_root/status.out" "$conflict_entry" conflict
      assert_conflict_intact "$conflict_kind" "$conflict_path"
      assert_absent "$other_path"

      assert_failure run_installer_quiet install "$case_root/install.out"
      assert_conflict_intact "$conflict_kind" "$conflict_path"
      assert_absent "$other_path"

      create_current_link "$other_path" "$other_source" relative
      other_raw=$(readlink "$other_path")
      assert_failure run_installer_quiet uninstall "$case_root/uninstall.out"
      assert_conflict_intact "$conflict_kind" "$conflict_path"
      assert_current_link_at "$other_path" "$other_source"
      [ "$(readlink "$other_path")" = "$other_raw" ] || fail "uninstall replaced $other_entry beside conflict"
    done
  done
}

write_fault_ln() {
  fault_bin="$case_root/fault-bin"
  mkdir -p "$fault_bin"
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -eu' \
    'count=0' \
    'if [ -f "$OPCSKILLS_LN_FAULT_COUNT" ]; then read -r count < "$OPCSKILLS_LN_FAULT_COUNT"; fi' \
    'count=$((count + 1))' \
    'printf "%s\n" "$count" > "$OPCSKILLS_LN_FAULT_COUNT"' \
    'if [ "$count" -eq "$OPCSKILLS_LN_FAIL_AT" ]; then echo "injected link failure" >&2; exit 23; fi' \
    'exec "$OPCSKILLS_REAL_LN" "$@"' > "$fault_bin/ln"
  chmod +x "$fault_bin/ln"
}

run_fault_installer() {
  fail_at=$1
  output_file=$2
  HOME="$case_home" \
    OPCSKILLS_SKILLS_HOME="$skills_home" \
    OPCSKILLS_LN_FAULT_COUNT="$case_root/ln-count" \
    OPCSKILLS_LN_FAIL_AT="$fail_at" \
    OPCSKILLS_REAL_LN="$real_ln" \
    PATH="$fault_bin:$PATH" \
    "$script_path" install >"$output_file" 2>&1
}

run_rollback_cases() {
  new_case rollback-second
  write_fault_ln
  assert_failure run_fault_installer 2 "$case_root/install.out"
  [ "$(cat "$case_root/ln-count")" -eq 2 ] || fail "second-link failure was not injected"
  grep -q 'newly created entrypoints were rolled back' "$case_root/install.out" || fail "rollback message missing"
  assert_absent "$skills_home/opc-skills"
  assert_absent "$skills_home/zx-skills"

  new_case rollback-preserve-current
  create_current_link "$skills_home/opc-skills" "$opc_source" relative
  opc_raw=$(readlink "$skills_home/opc-skills")
  write_fault_ln
  assert_failure run_fault_installer 1 "$case_root/install.out"
  [ "$(cat "$case_root/ln-count")" -eq 1 ] || fail "missing-link failure was not injected"
  assert_current_link_at "$skills_home/opc-skills" "$opc_source"
  [ "$(readlink "$skills_home/opc-skills")" = "$opc_raw" ] || fail "rollback replaced pre-existing opc-skills"
  assert_absent "$skills_home/zx-skills"
}

run_fresh_lifecycle_case
run_legacy_upgrade_case
run_status_matrix
run_fallback_case
run_relative_idempotency_case
run_conflict_matrix
run_rollback_cases

[ "$HOME" = "$original_home" ] || fail "test changed parent HOME"
echo "PASS: POSIX Codex installer covers dual-entry lifecycle, status, conflicts, fallback, idempotency, and rollback"
