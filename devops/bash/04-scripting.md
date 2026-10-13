# Writing scripts

[← Bash 101](README.md)

How to write Bash scripts that are safe to run on production servers: they stop on errors, explain themselves, clean up after themselves, can be previewed, and can be run twice without harm. Then how to lint, test, install, and schedule them. Every practice here is used in [scripts/](scripts/); [template.sh](scripts/template.sh) has all of them in one place.

**When not to use Bash:** past a few hundred lines, or when you need data structures, real error handling, JSON manipulation, or unit tests of business logic, use Python (or Go). For configuring many servers, use configuration management (Ansible) or images. Bash is excellent glue; it's a poor application language.

---

## Setting up a new script, step by step

### 1. Start from the template

```sh
cp devops/bash/scripts/template.sh ~/bin/rotate-app-logs.sh
chmod +x ~/bin/rotate-app-logs.sh
```

Name scripts for what they do, with a verb: `rotate-app-logs.sh`, not `script2.sh`. Keep `lib/common.sh` next to it, or copy in the functions you use.

### 2. The first lines

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
```

| Line | Why |
|---|---|
| `#!/usr/bin/env bash` | The *shebang*: run with Bash from the `PATH`. Use Bash, not `sh`: on Ubuntu, `/bin/sh` is dash, which lacks arrays, `[[ ]]`, and more. |
| `set -e` | Exit as soon as a command fails, instead of carrying on with bad state |
| `set -u` | Treat unset variables as errors. Catches typos like `rm -rf "$PERFIX/"` that would otherwise expand to `rm -rf /` |
| `set -o pipefail` | A pipeline fails if any command in it fails, not just the last. Without it, `grep x missing.log \| sort` "succeeds" |
| `set -E` | Lets an `ERR` trap fire inside functions too |
| `IFS=$'\n\t'` | Split words only on newlines and tabs, not spaces, so file names with spaces survive (quote anyway) |

### 3. Know the strict-mode traps

`set -e` has rules that surprise everyone at least once. These caught real bugs while writing this folder:

| Code | What happens | Write instead |
|---|---|---|
| `[[ -n "$x" ]] && echo "$x"` as the **last** command of a function, block, or loop body | When the test is false, the block returns 1. With `-e` and `pipefail`, the script exits silently. | `if [[ -n "$x" ]]; then echo "$x"; fi` |
| `count=$(grep -c pattern file)` | `grep -c` exits 1 when the count is 0, which kills the script | `count=$(grep -c pattern file \|\| true)` |
| `((i++))` when `i` is 0 | Arithmetic that evaluates to 0 counts as failure | `i=$((i + 1))` |
| `local out=$(cmd)` | `local` hides `cmd`'s failure: the line always succeeds | `local out; out=$(cmd)` |
| A function called in `if myfunc; then` | `-e` is ignored inside it, for the whole call | Check errors explicitly inside functions used as conditions |

When a command is *expected* to fail sometimes, say so: `cmd || true`, or handle it with `if`.

### 4. Structure: functions and a main

```bash
main() {
  parse_args "$@"
  check_prerequisites
  do_the_work
}

# Run main only when executed, not when sourced by a test.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
```

Keep top-level code to setup and the call to `main`. Use `local` for every variable inside functions. Put constants at the top in `UPPER_CASE`; use `lower_case` for locals.

### 5. Arguments and help

Parse with a `while`/`case` loop: it handles long options (`--dry-run`), short ones (`-n`), values (`--output DIR` and `--output=DIR`), and `--` to end options, which the `getopts` built-in can't do with long options.

```bash
while (($# > 0)); do
  case "$1" in
    -n | --dry-run) DRY_RUN=1 ;;
    -o | --output)
      [[ $# -ge 2 ]] || die "$1 needs a value" 2
      OUTPUT_DIR="$2"
      shift
      ;;
    --output=*) OUTPUT_DIR="${1#*=}" ;;   # strip everything up to the first "="
    -h | --help) usage; exit 0 ;;
    --) shift; break ;;
    -*) die "Unknown option: $1" 2 ;;
    *) TARGETS+=("$1") ;;
  esac
  shift
done
```

Write the help as the comment block at the top of the file, and print it with `usage() { sed -n '3,/^$/s/^# \{0,1\}//p' "$0"; }`. The documentation and the help can't drift apart, because they're the same text.

**Validate every input before changing anything.** The scripts here check user names, hostnames, ports, and firewall rules with regexes ([Regular expressions](03-regex.md#pattern-library)) before the first change, so a typo fails fast with exit code 2 (the convention for bad usage) instead of half-applying.

### 6. Logging and exit codes

- **Log to stderr** (`>&2`), so stdout carries only the script's output and can be piped.
- **Prefix with a timestamp and level,** as `log_info`, `log_warn`, and `log_error` in [lib/common.sh](scripts/lib/common.sh) do.
- **Exit codes:** 0 success, 1 failure, 2 bad usage, and pass through a failing command's own code where it's meaningful (as [retry.sh](scripts/retry.sh) does).
- **Under systemd, just print.** Output to stdout and stderr goes to the journal automatically. From cron or elsewhere, use `logger -t myscript "message"` to send to syslog.

### 7. Make it previewable: --dry-run

Route every command that changes the system through one function, so a dry run is honest:

```bash
run() {
  if [[ "$DRY_RUN" == 1 ]]; then
    printf '[dry-run]'; printf ' %q' "$@"; printf '\n'   # %q: shell-quoted, exactly as it would run
    return 0
  fi
  "$@"
}

run systemctl restart nginx
```

Read-only commands (checks, `grep`, `stat`) run normally in a dry run, so the preview reflects the real system.

### 8. Clean up, always

```bash
WORK_DIR="$(mktemp -d)"                 # never a fixed /tmp/myscript path: unsafe and collides
cleanup() { rm -rf -- "$WORK_DIR"; }
trap cleanup EXIT                       # runs on success, failure, and exit
trap 'log_error "Failed at line $LINENO: $BASH_COMMAND"' ERR
```

### 9. One at a time: locking

A script run from a timer can overlap with the previous run. `flock` prevents it:

```bash
exec 9>/var/lock/rotate-app-logs.lock   # open file descriptor 9 on the lock file
flock -n 9 || die "Already running"     # -n: fail at once instead of waiting
```

The lock is released automatically when the script exits, even if it crashes. ([backup-rotate.sh](scripts/backup-rotate.sh) does this.)

### 10. Make it idempotent

Running twice must leave the same result as running once, so a script can be re-run after a failure, or run on every boot:

| Not idempotent | Idempotent |
|---|---|
| `echo "setting" >> file` (adds a line every run) | Write the whole file, or check first: `grep -qx 'setting' file \|\| echo 'setting' >> file` |
| `useradd deploy` (fails the second time) | `id deploy &>/dev/null \|\| useradd deploy` |
| `mkdir /srv/app` | `mkdir -p /srv/app` |
| Editing a config with `sed -i` that appends | A drop-in file you own entirely, such as `/etc/ssh/sshd_config.d/10-hardening.conf` |

Write config files atomically (to a temp file, then `mv`), so a crash never leaves half a file: see `write_file` in [lib/common.sh](scripts/lib/common.sh). And validate before activating: `sshd -t`, `visudo -cf`, `nginx -t`, `named-checkconf`, then reload.

### 11. Safe coding habits

```bash
"$var"                       # always quote expansions
"${files[@]}"                # arrays, quoted, for lists of things
while IFS= read -r line; do  # read lines exactly: no trimming, no backslash processing
  ...
done < file
for f in ./*.log; do         # glob directly; never parse ls output
  [[ -e "$f" ]] || continue  # the glob matched nothing
done
rm -rf -- "${dir:?}/"        # ${dir:?} aborts if dir is empty; -- ends options
cd "$dir" || exit            # cd can fail
command -v jq >/dev/null || die "jq is required"
```

### 12. Debug

```bash
bash -n script.sh            # syntax check only
bash -x script.sh args       # trace every command as it runs
PS4='+ ${BASH_SOURCE##*/}:${LINENO}: ' bash -x script.sh   # trace with file and line numbers
set -x; risky_part; set +x   # trace just one section
```

---

## Lint and format

[ShellCheck](https://www.shellcheck.net/) finds bugs: unquoted variables, useless `cat`, wrong test syntax, and the strict-mode traps above. [shfmt](https://github.com/mvdan/sh) formats consistently. Run both on every change; CI does for this folder.

```sh
# Install: dnf install ShellCheck (from EPEL on RHEL), apt install shellcheck; shfmt from its releases or a container
shellcheck -x script.sh                 # -x: follow "source" lines
shfmt -d -i 2 -ci script.sh             # show the diff; -w to rewrite. 2-space indent, indented case branches

# Or without installing anything:
docker run --rm -v "$PWD:/mnt" -w /mnt koalaman/shellcheck:v0.11.0 -x script.sh
docker run --rm -v "$PWD:/mnt" -w /mnt mvdan/shfmt:v3.14.1 -d -i 2 -ci script.sh
```

When ShellCheck is wrong for a specific line, disable that one check on that line with a reason: `# shellcheck disable=SC2016 # expands in the child shell`. Never disable checks globally to make the noise stop.

Editor plugins for VS Code and Vim run ShellCheck as you type.

## Test with Bats

[Bats](https://github.com/bats-core/bats-core) (Bash Automated Testing System) runs tests written in Bash. Each `@test` passes if every command in it succeeds. `run` captures a command's `$status` and `$output`:

```bash
#!/usr/bin/env bats

@test "retry: returns the command's exit code after the last attempt" {
  run bash scripts/retry.sh -n 2 -d 1 -- bash -c 'exit 7'
  [ "$status" -eq 7 ]
  [[ "$output" == *"Failed after 2 attempt(s)"* ]]
}
```

```sh
dnf install bats    # EPEL on RHEL; apt install bats on Ubuntu
bats devops/bash/tests     # every .bats file in the folder
```

[tests/scripts.bats](tests/scripts.bats) tests the library and every script's argument handling; [tests/regex.bats](tests/regex.bats) tests every pattern in the regex guide. Test what doesn't need root with Bats, and test what does in a throwaway container, as [tests/integration.sh](tests/integration.sh) does.

---

## Install it

A standalone script installs as one file:

```sh
sudo install -m 0755 rotate-app-logs.sh /usr/local/sbin/rotate-app-logs   # sbin for admin tools; bin for everyone
sudo install -d -m 0755 /etc/rotate-app-logs                              # its configuration, if any
```

Scripts that source `lib/common.sh`, like the ones in this folder, install as a folder with links to the commands. They find their library by resolving the link (`readlink -f`), so the link can live anywhere:

```sh
sudo cp -r devops/bash/scripts /opt/ops-scripts
sudo chmod 0755 /opt/ops-scripts/*.sh
sudo ln -sf /opt/ops-scripts/backup-rotate.sh /usr/local/sbin/backup-rotate
sudo ln -sf /opt/ops-scripts/system-report.sh /usr/local/sbin/system-report
```

`/usr/local` and `/opt` belong to you, not the package manager, on both RHEL and Ubuntu. For fleets, package scripts as an RPM or a .deb, or deliver them with configuration management, so every host has the same version.

## Scheduling

### systemd timers (preferred)

A timer starts a service on a schedule. Compared with cron, you get logs in the journal, no overlapping runs, catch-up after downtime (`Persistent=true`), randomized start times, resource limits, and `systemctl list-timers` to see what's next. Both RHEL and Ubuntu use systemd.

`/etc/systemd/system/backup-www.service`:

```ini
[Unit]
Description=Back up /srv/www
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/backup-rotate --keep 14 /srv/www /var/backups/www
# Sandboxing: read-only system, private /tmp, no new privileges
ProtectSystem=strict
ReadWritePaths=/var/backups/www
PrivateTmp=true
NoNewPrivileges=true
Nice=10
IOSchedulingClass=idle
```

`/etc/systemd/system/backup-www.timer`:

```ini
[Unit]
Description=Back up /srv/www nightly

[Timer]
OnCalendar=*-*-* 02:30:00
RandomizedDelaySec=15m
Persistent=true

[Install]
WantedBy=timers.target
```

```sh
sudo systemctl daemon-reload
sudo systemctl enable --now backup-www.timer
systemctl list-timers backup-www.timer          # next and last run
sudo systemctl start backup-www.service         # run it now, to test
journalctl -u backup-www.service -n 50          # its output
systemd-analyze calendar '*-*-* 02:30:00'       # check an OnCalendar expression
```

`OnCalendar` examples: `hourly`, `daily`, `Mon..Fri 08:00`, `*-*-01 03:00` (first of the month), `*:0/15` (every 15 minutes).

### cron

Still everywhere, and fine for simple jobs. The package is `cronie` on RHEL and `cron` on Ubuntu.

```text
# m  h  dom mon dow  command
30   2  *   *   *    /usr/local/sbin/backup-rotate --keep 14 /srv/www /var/backups/www >> /var/log/backup-www.log 2>&1
*/15 *  *   *   1-5  flock -n /run/lock/sync.lock /usr/local/bin/sync-reports
```

Edit with `crontab -e` (your user) or put a file in `/etc/cron.d/` (system jobs, with a user field after the schedule). The traps:

- **Minimal environment:** cron's `PATH` is short (`/usr/bin:/bin`). Use full paths or set `PATH=` at the top of the crontab.
- **`%` is special** in crontab lines (it means newline). Escape it: `date +\%F`.
- **Output** is emailed to the user, or lost. Redirect it to a log, or use `logger`.
- **No overlap protection.** Wrap long jobs in `flock -n`.
- **Check the schedule** with a tool such as [crontab.guru](https://crontab.guru/) before trusting it.

## Running scripts on other machines

```sh
ssh web-01 'bash -s' < system-report.sh                      # run a local script remotely, no copy needed
ssh web-01 'bash -s -- --disk-threshold 90' < system-report.sh   # with arguments
for h in web-01 web-02 web-03; do ssh "$h" 'uptime'; done     # several hosts, in turn
printf '%s\n' web-0{1..3} | xargs -P3 -I{} ssh {} 'hostname; uptime'   # several hosts, in parallel
```

For more than a handful of hosts, use Ansible: it does this with inventory, parallelism, error handling, and idempotent modules.

---

## Checklist for a script going to production

- [ ] Shebang `#!/usr/bin/env bash` and `set -Eeuo pipefail`
- [ ] `--help` from a header comment, describing every option and the exit codes
- [ ] Every input validated before the first change; bad usage exits 2
- [ ] Every change goes through `run`, and `--dry-run` works
- [ ] Temp files from `mktemp`, removed by a `trap ... EXIT`
- [ ] Idempotent: a second run changes nothing
- [ ] Configs written atomically and validated (`sshd -t`, `visudo -c`, `nginx -t`) before reload
- [ ] Locking if it can run on a schedule
- [ ] ShellCheck and shfmt clean
- [ ] Tested: Bats for logic, a throwaway container or VM of each target distribution for the rest
- [ ] Installed to `/usr/local/sbin` (or packaged), scheduled with a systemd timer, logs in the journal
