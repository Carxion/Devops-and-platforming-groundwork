# Complex commands, broken down

[← Bash 101](README.md)

Long one-liners look like line noise until you read them as a pipeline: each `|` passes one program's output to the next, and each stage does one small job. Every command here is broken into its parts. Where it uses the sample logs in [tests/fixtures](tests/fixtures/), the output shown is real.

How to read any pipeline: **run it one stage at a time.** Run the first command alone, look at the output, add the next `| stage`, look again. That's also how to write them.

---

## 1. Count requests per status code

```sh
awk '{ print $9 }' tests/fixtures/access.log | sort | uniq -c | sort -rn
#   6 200
#   1 503
#   1 500
#   1 404
#   1 401
```

| Stage | Does |
|---|---|
| `awk '{ print $9 }' file` | Splits each line on whitespace and prints field 9, the status code in the combined log format |
| `sort` | Groups identical codes together (`uniq` only collapses *adjacent* duplicates) |
| `uniq -c` | Collapses each group to one line, prefixed with its count |
| `sort -rn` | Sorts by that count: `-n` numerically, `-r` largest first |

Swap `$9` for `$1` (client IP) or `$7` (path) to answer different questions. [log-summary.sh](scripts/log-summary.sh) does all of these at once.

## 2. Requests per minute, to find a spike

```sh
awk -F'[][]' '{ print substr($2, 1, 17) }' tests/fixtures/access.log | uniq -c
#  10 13/Oct/2026:08:00
```

| Stage | Does |
|---|---|
| `-F'[][]'` | The field separator is a regex: a bracket expression containing `]` and `[`. So `$2` is the text between `[` and `]`: the timestamp |
| `substr($2, 1, 17)` | The first 17 characters, `13/Oct/2026:08:00`: the timestamp truncated to the minute |
| `uniq -c` | Counts consecutive identical minutes. No `sort` needed, because log lines are already in time order |

Change 17 to 14 for per-hour counts, or to 20 for per-second.

## 3. The biggest files on a filesystem

```sh
sudo find / -xdev -type f -size +100M -printf '%s\t%p\n' 2>/dev/null | sort -rn | head -10 | numfmt --field=1 --to=iec
```

| Stage | Does |
|---|---|
| `find / -xdev` | Search from `/`, but don't descend into other mounted filesystems (`/proc`, other disks) |
| `-type f -size +100M` | Regular files larger than 100 MiB |
| `-printf '%s\t%p\n'` | Print the size in bytes, a tab, and the path (GNU find) |
| `2>/dev/null` | Discard permission-denied errors |
| `sort -rn \| head -10` | Largest ten, by the byte count at the start of the line |
| `numfmt --field=1 --to=iec` | Turn the first field into a human size: `1073741824` becomes `1.0G` |

## 4. Files a process deleted but still holds open

```sh
sudo lsof -nP +L1 2>/dev/null | awk 'NR > 1 { printf "%-15s %-7s %10.1f MB  %s\n", $1, $2, $7 / 1048576, $NF }' | sort -k3 -rn | head
```

| Stage | Does |
|---|---|
| `lsof +L1` | List open files with fewer than 1 link: deleted from the directory, but still open, so their space isn't freed |
| `-nP` | Don't resolve host names or port names (faster) |
| `awk 'NR > 1'` | Skip the header line |
| `printf "%-15s %-7s %10.1f MB  %s\n", $1, $2, $7 / 1048576, $NF` | Command (left-aligned, 15 wide), PID, size in MB (field 7 is the size in bytes), and the last field, the file name |
| `sort -k3 -rn` | By the third column, the size, largest first |

The fix is to restart the process holding the file (usually a service that wasn't told its log was rotated).

## 5. Find and replace across many files, safely

```sh
grep -rlZ --include='*.conf' 'old-db.internal' /etc/app/ | xargs -0 -r sed -i.bak 's/old-db\.internal/new-db.internal/g'
```

| Stage | Does |
|---|---|
| `grep -r` | Search recursively |
| `-l` | Print only the names of files that contain a match |
| `-Z` | End each name with a NUL byte instead of a newline, so names with spaces or newlines survive |
| `--include='*.conf'` | Only files whose name matches the glob |
| `xargs -0` | Read NUL-separated names and pass them as arguments |
| `-r` | Don't run at all if there were no matches (GNU xargs) |
| `sed -i.bak 's/.../.../g'` | Edit each file in place, keeping a `.bak` copy. The dots are escaped (`\.`) in the pattern, so `.` matches only a literal dot |

Preview first: run the `grep` alone to see which files will change, and run `sed` without `-i` on one of them to see how.

## 6. Delete old files, with a preview

```sh
find /var/log/app -type f -name '*.log.gz' -mtime +30 -print            # preview
find /var/log/app -type f -name '*.log.gz' -mtime +30 -print -delete    # then delete, printing each
```

| Part | Does |
|---|---|
| `-mtime +30` | Modified more than 30 full days ago (`-mtime -1` is "within the last day"; `-mmin` counts minutes) |
| `-print -delete` | Print each file as it's deleted. **`-delete` must come last**: `find -delete -name x` deletes everything before it gets to the name test |

## 7. Compare installed packages between two servers

```sh
diff <(ssh web-01 'rpm -qa --qf "%{NAME}\n" | sort') <(ssh web-02 'rpm -qa --qf "%{NAME}\n" | sort')
```

| Part | Does |
|---|---|
| `<( ... )` | **Process substitution**: runs the command and presents its output as a file name (like `/dev/fd/63`), so tools that want files can read command output |
| `rpm -qa --qf "%{NAME}\n"` | All installed packages, names only (no versions, so only differences in *what* is installed show) |
| `sort` | `diff` needs both lists in the same order |
| `diff a b` | Lines starting `<` exist only on web-01, `>` only on web-02 |

On Ubuntu, use `dpkg-query -W -f='${Package}\n'` instead of `rpm -qa --qf`. Include `%{VERSION}` (or `${Version}`) to find version drift too.

## 8. Health-check many hosts in parallel

```sh
printf '%s\n' web-0{1..6}.internal | xargs -P6 -I{} sh -c 'printf "%-18s %s\n" {} "$(curl -fsS -m 3 -o /dev/null -w "%{http_code}" https://{}/healthz || echo DOWN)"'
```

| Part | Does |
|---|---|
| `web-0{1..6}.internal` | Brace expansion: `web-01.internal` through `web-06.internal` |
| `printf '%s\n'` | One host per line, for xargs |
| `xargs -P6` | Run up to six at a time |
| `-I{}` | One command per input line, replacing `{}` with the line |
| `curl -fsS -m 3` | Fail on HTTP errors (`-f`), silent but show errors (`-sS`), three-second timeout (`-m 3`) |
| `-o /dev/null -w "%{http_code}"` | Throw away the body; print only the status code |
| `\|\| echo DOWN` | If curl failed (timeout, refused, 5xx), print DOWN instead |

## 9. Certificate expiry for a list of hosts

```sh
for h in example.com example.org; do
  end=$(echo | openssl s_client -connect "$h:443" -servername "$h" 2>/dev/null | openssl x509 -noout -enddate | cut -d= -f2)
  printf '%-20s %s (%d days)\n' "$h" "$end" $(( ($(date -d "$end" +%s) - $(date +%s)) / 86400 ))
done
```

| Part | Does |
|---|---|
| `echo \|` | Sends an empty line so `s_client` disconnects as soon as the handshake is done |
| `openssl s_client -connect "$h:443" -servername "$h"` | Open a TLS connection; `-servername` sends SNI, without which shared hosts return the wrong certificate |
| `openssl x509 -noout -enddate` | Parse the certificate from that output and print `notAfter=...` |
| `cut -d= -f2` | Keep what's after the `=`: the date |
| `date -d "$end" +%s` | Convert the date to seconds since 1970 (GNU date) |
| `$(( (a - b) / 86400 ))` | Arithmetic: seconds remaining divided by seconds in a day |

## 10. Watch a log and act on a pattern

```sh
tail -Fn0 /var/log/app/app.log | grep --line-buffered -E 'FATAL|OutOfMemory' | while read -r line; do
  logger -t app-watch "Alert: $line"
done
```

| Part | Does |
|---|---|
| `tail -F` | Follow the file, and keep following across rotation (when the file is replaced) |
| `-n0` | Start at the end: only new lines, not the last ten |
| `grep --line-buffered` | Pass each match on immediately. Without it, grep buffers output when writing to a pipe, and lines arrive in delayed bursts |
| `while read -r line` | Handle each matching line; `-r` keeps backslashes literal |
| `logger -t app-watch` | Send a message to syslog and the journal, tagged `app-watch` |

For anything important, use real alerting on logs ([observability](../observability/README.md)) instead; this is for a quick watch during an incident.

## 11. Copy a directory between hosts with no temporary file

```sh
tar -C /srv -czf - www | ssh web-02 'sudo tar -C /srv -xzf -'
```

| Part | Does |
|---|---|
| `tar -C /srv` | Change to `/srv` first, so the archive holds `www/...` rather than `/srv/www/...` |
| `-czf -` | Create, gzip, and write the archive to `-`: standard output |
| `\| ssh web-02 '...'` | Stream it over SSH |
| `tar -C /srv -xzf -` | On the far side, extract from standard input into `/srv` |

`rsync -az --delete /srv/www/ web-02:/srv/www/` is usually better: it copies only what changed and can resume. The tar form wins for a one-off copy of many small files, or where rsync isn't installed.

## 12. Which config files differ from the package defaults

```sh
sudo rpm -Va --nomtime 2>/dev/null | awk '$1 ~ /5/ && $2 == "c" { print $3 }'    # RHEL
sudo debsums -ce 2>/dev/null                                                      # Ubuntu (package debsums)
```

| Part | Does |
|---|---|
| `rpm -Va` | Verify every installed file against the package database: size, mode, checksum, owner... |
| `--nomtime` | Ignore modification times, which change for many harmless reasons |
| `$1 ~ /5/` | The first column is a set of flags; `5` means the checksum (content) differs |
| `$2 == "c"` | The second column marks config files with `c` |
| `debsums -ce` | Changed (`-c`) configuration files (`-e`) |

Useful on a server you inherit: these are the files someone changed by hand.

## 13. Memory used per program name

```sh
ps -eo rss=,comm= | awk '{ mem[$2] += $1 } END { for (p in mem) printf "%8.1f MB  %s\n", mem[p] / 1024, p }' | sort -rn | head
```

| Part | Does |
|---|---|
| `ps -eo rss=,comm=` | Every process: resident memory in KB and command name. `=` after a column name suppresses the header |
| `mem[$2] += $1` | An associative array keyed by program name, summing memory across its processes (all the php-fpm or postgres workers together) |
| `END { for (p in mem) ... }` | After all input, print each total, converted to MB |
| `sort -rn \| head` | Largest first |

Shared memory is counted once per process, so totals for programs with many workers are overstated. `systemctl status` or `systemd-cgtop` shows the true memory per service.

## 14. Lines between two times in a log

```sh
awk '$0 >= "2026-10-13T08:00" && $0 < "2026-10-13T08:15"' app.log
```

| Part | Does |
|---|---|
| `$0 >= "..."` | Compares the whole line as a string. ISO 8601 timestamps sort alphabetically in time order, so a string comparison is a time comparison |
| `&& $0 < "..."` | Before the end time |

This only works when lines start with an ISO timestamp, which is one more reason to log in ISO 8601 UTC. For the journal, use `journalctl --since "2026-10-13 08:00" --until "2026-10-13 08:15"`.

## 15. Users who can log in, and when they last did

```sh
awk -F: '$3 >= 1000 && $7 !~ /(nologin|false)$/ { print $1 }' /etc/passwd | while read -r u; do
  printf '%-15s %s\n' "$u" "$(lastlog -u "$u" 2>/dev/null | awk 'NR == 2 { $1 = ""; print }')"
done
```

| Part | Does |
|---|---|
| `awk -F: '$3 >= 1000 ...'` | Split `/etc/passwd` on `:`. Field 3 is the UID (1000 and up are regular users on both families), field 7 the shell |
| `$7 !~ /(nologin\|false)$/` | Skip accounts whose shell ends in `nologin` or `false`: they can't log in interactively |
| `while read -r u` | For each user name |
| `lastlog -u "$u"` | That user's most recent login |
| `awk 'NR == 2 { $1 = ""; print }'` | Line 2 (after the header), without the first field (the name again) |

Recent Ubuntu releases replace `lastlog` with `lastlog2`; `last -n 1 "$u"` works on both.

## 16. Kill processes older than an hour, by name

```sh
ps -eo pid=,etimes=,comm= | awk '$3 == "report-worker" && $2 > 3600 { print $1 }' | xargs -r kill -TERM
```

| Part | Does |
|---|---|
| `ps -eo pid=,etimes=,comm=` | PID, elapsed time in **seconds** (`etimes`, not `etime`), and name, without headers |
| `$3 == "report-worker" && $2 > 3600` | Exact name match, running more than an hour |
| `xargs -r kill -TERM` | Send TERM to each PID; do nothing if there are none |

Run it without the `| xargs ...` part first to see the PIDs.

## 17. Rename many files

```sh
for f in ./*.jpeg; do [[ -e "$f" ]] || continue; mv -n -- "$f" "${f%.jpeg}.jpg"; done
```

| Part | Does |
|---|---|
| `for f in ./*.jpeg` | Loop over matching files. `./` keeps names that start with `-` from looking like options |
| `[[ -e "$f" ]] \|\| continue` | If nothing matched, the glob stays as the literal `./*.jpeg`; skip it |
| `${f%.jpeg}` | Parameter expansion: remove the shortest `.jpeg` suffix |
| `mv -n --` | Don't overwrite an existing file (`-n`); `--` ends options |

## 18. Read a key=value file safely, without sourcing it

```sh
declare -A conf
while IFS='=' read -r key value; do
  [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue     # skip comments, blanks, and anything odd
  conf["$key"]="$value"
done < /etc/app/app.env
echo "${conf[DB_HOST]}"
```

| Part | Does |
|---|---|
| `declare -A conf` | An associative array (a dictionary) |
| `IFS='=' read -r key value` | Split each line at the first `=`; anything after further `=` signs stays in `value` |
| `[[ "$key" =~ ... ]] \|\| continue` | Accept only valid variable names, which also skips `#` comments and blank lines |
| `< /etc/app/app.env` | Feed the file into the loop |

`source app.env` would *execute* the file, so anyone who can edit it can run commands as whoever sources it. Reading it as data can't.

## 19. Dates and times

```sh
date -u +%Y-%m-%dT%H:%M:%SZ          # now, ISO 8601 UTC: 2026-10-13T08:00:01Z
date -d @1791936000 -u               # epoch seconds to a date
date -d '2026-10-13 08:00 UTC' +%s   # a date to epoch seconds
date -d '-7 days' +%F                # a week ago: 2026-10-06
date -d 'next monday' +%F
```

All GNU `date`, the same on RHEL and Ubuntu (macOS `date` differs).

## 20. A quick table from mixed output

```sh
{ echo "MOUNT SIZE USED USE%"; df -h --output=target,size,used,pcent -x tmpfs -x devtmpfs | tail -n +2; } | column -t
```

| Part | Does |
|---|---|
| `{ ...; ...; }` | A group: both commands' output goes into one pipe (the spaces and the final `;` are required) |
| `df -h --output=...` | Only the chosen columns (GNU df) |
| `tail -n +2` | From line 2 on: drop df's own header, since we wrote one |
| `column -t` | Align everything into a table |
