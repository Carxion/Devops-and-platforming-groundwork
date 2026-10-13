#!/usr/bin/env bats
# Unit tests for bash/scripts that don't need root: the shared library,
# argument handling, and the utility scripts. Run: bats bash/tests
# (Root-level behavior is covered by tests/integration.sh in containers.)

setup() {
  S="$BATS_TEST_DIRNAME/../scripts"
  F="$BATS_TEST_DIRNAME/fixtures"
  TMP="$BATS_TEST_TMPDIR"
  export NO_COLOR=1
}

os_release() { printf '%s\n' "$@" >"$TMP/os-release"; }

detect() {
  # Run detect_os in a fresh shell against a fake /etc/os-release.
  OS_RELEASE_FILE="$TMP/os-release" bash -c "source '$S/lib/common.sh'; detect_os; echo \"\$OS_ID \$OS_FAMILY \$PKG\""
}

# --- lib/common.sh -----------------------------------------------------------

@test "detect_os: Ubuntu" {
  os_release 'ID=ubuntu' 'ID_LIKE=debian' 'VERSION_ID="24.04"'
  [ "$(detect)" = "ubuntu debian apt" ]
}

@test "detect_os: RHEL" {
  os_release 'ID="rhel"' 'ID_LIKE="fedora"' 'VERSION_ID="9.4"'
  [ "$(detect)" = "rhel rhel dnf" ]
}

@test "detect_os: Rocky and AlmaLinux via ID_LIKE" {
  os_release 'ID="rocky"' 'ID_LIKE="rhel centos fedora"'
  [ "$(detect)" = "rocky rhel dnf" ]
  os_release 'ID="almalinux"' 'ID_LIKE="rhel centos fedora"'
  [ "$(detect)" = "almalinux rhel dnf" ]
}

@test "detect_os: Debian" {
  os_release 'ID=debian' 'VERSION_ID="12"'
  [ "$(detect)" = "debian debian apt" ]
}

@test "detect_os: unsupported distribution fails clearly" {
  os_release 'ID=alpine'
  run detect
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unsupported distribution: alpine"* ]]
}

@test "detect_os doesn't leak os-release variables" {
  os_release 'ID=ubuntu' 'NAME=Ubuntu' 'PRETTY_NAME=leak'
  run bash -c "source '$S/lib/common.sh'; OS_RELEASE_FILE='$TMP/os-release' detect_os; echo \"[\${PRETTY_NAME:-}]\""
  [ "$output" = "[]" ]
}

@test "run: dry run prints the command, quoted, and doesn't run it" {
  run bash -c "source '$S/lib/common.sh'; DRY_RUN=1; run touch '$TMP/a file' 2>&1"
  [ "$status" -eq 0 ]
  [[ "$output" == *'[dry-run] touch'*'a\ file'* ]]
  [ ! -e "$TMP/a file" ]
}

@test "run: executes for real without DRY_RUN" {
  bash -c "source '$S/lib/common.sh'; run touch '$TMP/real'"
  [ -e "$TMP/real" ]
}

@test "write_file: writes content with the given mode" {
  bash -c "source '$S/lib/common.sh'; printf 'hello\n' | write_file '$TMP/out.conf' 0600"
  [ "$(cat "$TMP/out.conf")" = hello ]
  [ "$(stat -c %a "$TMP/out.conf")" = 600 ]
  # No temp files left behind.
  [ "$(find "$TMP" -name 'out.conf.*' | wc -l)" -eq 0 ]
}

@test "confirm: ASSUME_YES skips the prompt" {
  run bash -c "source '$S/lib/common.sh'; ASSUME_YES=1 confirm 'Go?' && echo yes"
  [ "$output" = yes ]
}

@test "confirm: accepts y and yes, rejects anything else" {
  run bash -c "source '$S/lib/common.sh'; confirm 'Go?' <<<'yes' && echo ok"
  [ "${lines[-1]}" = ok ]
  run bash -c "source '$S/lib/common.sh'; confirm 'Go?' <<<'yep' || echo no"
  [ "${lines[-1]}" = no ]
}

# --- template.sh -------------------------------------------------------------

@test "template: --help prints usage and exits 0" {
  run bash "$S/template.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: template.sh"* ]]
  [[ "$output" == *"--dry-run"* ]]
}

@test "template: unknown option exits 2" {
  run bash "$S/template.sh" --bogus x
  [ "$status" -eq 2 ]
  [[ "$output" == *"Unknown option: --bogus"* ]]
}

@test "template: missing target exits 2" {
  run bash "$S/template.sh"
  [ "$status" -eq 2 ]
}

@test "template: dry run changes nothing" {
  run bash "$S/template.sh" --dry-run --output "$TMP/new-dir" one two
  [ "$status" -eq 0 ]
  [ ! -d "$TMP/new-dir" ]
}

@test "template: --output=DIR form works" {
  run bash "$S/template.sh" --output="$TMP/made" one
  [ "$status" -eq 0 ]
  [ -d "$TMP/made" ]
}

# --- retry.sh ----------------------------------------------------------------

@test "retry: succeeds once the command does" {
  echo 0 >"$TMP/count"
  # Fails twice, then succeeds.
  run bash "$S/retry.sh" -n 5 -d 1 -- bash -c "n=\$(( \$(cat '$TMP/count') + 1 )); echo \$n > '$TMP/count'; [ \$n -ge 3 ]"
  [ "$status" -eq 0 ]
  [ "$(cat "$TMP/count")" -eq 3 ]
}

@test "retry: returns the command's exit code after the last attempt" {
  run bash "$S/retry.sh" -n 2 -d 1 -- bash -c 'exit 7'
  [ "$status" -eq 7 ]
  [[ "$output" == *"Failed after 2 attempt(s), last exit code 7"* ]]
}

@test "retry: requires a command after --" {
  run bash "$S/retry.sh" -n 2
  [ "$status" -eq 2 ]
}

# --- wait-for-port.sh --------------------------------------------------------

@test "wait-for-port: rejects a malformed target" {
  run bash "$S/wait-for-port.sh" localhost
  [ "$status" -eq 2 ]
}

@test "wait-for-port: times out on a closed port" {
  run bash "$S/wait-for-port.sh" -t 2 127.0.0.1:1
  [ "$status" -eq 1 ]
  [[ "$output" == *"Timed out after 2s"* ]]
}

@test "wait-for-port: succeeds on an open port and runs the command" {
  command -v nc >/dev/null || skip "nc not installed"
  nc -l 127.0.0.1 18080 >/dev/null 2>&1 &
  listener=$!
  run bash "$S/wait-for-port.sh" -t 5 127.0.0.1:18080 -- echo ready
  kill "$listener" 2>/dev/null || true
  [ "$status" -eq 0 ]
  [ "${lines[-1]}" = ready ]
}

# --- backup-rotate.sh --------------------------------------------------------

@test "backup-rotate: keeps the newest N archives, all valid" {
  mkdir -p "$TMP/data/sub"
  echo one >"$TMP/data/a.txt"
  echo log >"$TMP/data/sub/noise.log"
  for _ in 1 2 3; do
    bash "$S/backup-rotate.sh" --keep 2 --exclude '*.log' "$TMP/data" "$TMP/backups"
    sleep 1.1 # archive names have one-second resolution
  done
  [ "$(find "$TMP/backups" -name 'data-*.tar.gz' | wc -l)" -eq 2 ]
  newest="$(find "$TMP/backups" -name 'data-*.tar.gz' | sort | tail -1)"
  tar -tzf "$newest" | grep -qx 'data/a.txt'
  ! tar -tzf "$newest" | grep -q 'noise.log'
}

@test "backup-rotate: never deletes files it didn't create" {
  mkdir -p "$TMP/data" "$TMP/backups"
  echo x >"$TMP/data/f"
  touch "$TMP/backups/data-important.tar.gz" "$TMP/backups/other-20260101T000000Z.tar.gz"
  bash "$S/backup-rotate.sh" --keep 1 "$TMP/data" "$TMP/backups"
  [ -e "$TMP/backups/data-important.tar.gz" ]
  [ -e "$TMP/backups/other-20260101T000000Z.tar.gz" ]
}

# --- log-summary.sh ----------------------------------------------------------

@test "log-summary ssh: counts and top IPs from the fixture" {
  run bash "$S/log-summary.sh" ssh "$F/secure.log"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "SSH: 6 failed, 2 accepted, 2 attempts for users that do not exist" ]
  [[ "$output" == *"3 203.0.113.9"* ]]
  [[ "$output" == *"3 root"* ]]
  [[ "$output" == *"2 deploy from 192.0.2.10 (publickey)"* ]]
}

@test "log-summary ssh: reads gzipped logs" {
  gzip -c "$F/secure.log" >"$TMP/secure.log.1.gz"
  run bash "$S/log-summary.sh" ssh "$TMP/secure.log.1.gz"
  [ "${lines[0]}" = "SSH: 6 failed, 2 accepted, 2 attempts for users that do not exist" ]
}

@test "log-summary access: totals, statuses, and route collapsing" {
  run bash "$S/log-summary.sh" access "$F/access.log"
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == "Requests: 10, 5xx: 2 (20.00%)"* ]]
  [[ "$output" == *"4 GET /items/{id}"* ]]
  [[ "$output" == *"2 GET /healthz"* ]] # query string stripped
  [[ "$output" == *"1 500 GET /items/7"* ]]
}

@test "log-summary: requires a mode" {
  run bash "$S/log-summary.sh" "$F/access.log"
  [ "$status" -eq 2 ]
}

# --- argument validation that runs before the root check ---------------------

@test "create-admin-user: rejects an invalid user name" {
  run bash "$S/create-admin-user.sh" 'Bad Name' --ssh-key-file "$F/secure.log"
  [ "$status" -eq 2 ]
}

@test "configure-firewall: rejects a malformed rule" {
  run bash "$S/configure-firewall.sh" --allow 443
  [ "$status" -eq 2 ]
  run bash "$S/configure-firewall.sh" --allow 70000/tcp
  [ "$status" -eq 2 ]
}

@test "bootstrap-server: rejects an invalid hostname" {
  run bash "$S/bootstrap-server.sh" --dry-run --hostname -bad-
  [ "$status" -eq 2 ]
}

@test "a symlinked script still finds its library" {
  mkdir -p "$TMP/bin"
  ln -s "$S/retry.sh" "$TMP/bin/retry"
  run "$TMP/bin/retry" -n 1 -- true
  [ "$status" -eq 0 ]
}

@test "every script has --help" {
  for script in "$S"/*.sh; do
    run bash "$script" --help
    [ "$status" -eq 0 ] || {
      echo "$script --help exited $status"
      return 1
    }
    [[ "$output" == *"Usage:"* ]] || {
      echo "$script --help has no Usage line"
      return 1
    }
  done
}
