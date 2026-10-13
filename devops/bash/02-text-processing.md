# Text processing

[← Bash 101](README.md)

Logs, config files, command output, CSV exports: on Linux, almost everything is text, and a handful of small tools combine through pipes to answer almost any question about it. This guide covers each tool, then shows how they combine. The examples use the sample logs in [tests/fixtures](tests/fixtures/), so you can run them and compare.

| Tool | Job |
|---|---|
| `grep` | Find lines that match a pattern |
| `sed` | Edit lines: substitute, delete, print ranges |
| `awk` | Work with fields (columns): filter, compute, report |
| `cut`, `tr`, `paste`, `column` | Simple column and character operations |
| `sort`, `uniq`, `wc`, `head`, `tail` | Order, count, and trim |
| `find`, `xargs` | Find files, and run commands on many of them |
| `jq` | Query and transform JSON |

---

## grep

```sh
grep 'Failed password' tests/fixtures/secure.log            # lines containing the text
grep -c 'Failed password' tests/fixtures/secure.log         # how many lines: 5
grep -i 'failed' tests/fixtures/secure.log                  # ignore case
grep -v 'sshd' tests/fixtures/secure.log                    # lines NOT containing it
grep -E 'Failed|Invalid' tests/fixtures/secure.log          # either (ERE; see Regular expressions)
grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' tests/fixtures/secure.log   # print only the matched IPs
grep -n 'Accepted' tests/fixtures/secure.log                # with line numbers
grep -rn 'PermitRootLogin' /etc/ssh/                        # recursive, with file and line
grep -rl --include='*.conf' 'listen' /etc/nginx/            # just the file names, only .conf files
grep -A3 -B1 'ERROR' app.log                                # context: 3 lines after, 1 before
grep -F '[error]' app.log                                   # -F: fixed string, no regex (brackets are literal)
grep -q 'deploy' /etc/passwd && echo "user exists"          # -q: quiet, just the exit code
```

`zgrep` searches gzipped rotated logs (`zgrep 'Failed' /var/log/secure-*.gz` on RHEL, `/var/log/auth.log.*.gz` on Ubuntu).

## cut, tr, paste, column

```sh
cut -d: -f1,7 /etc/passwd           # fields 1 and 7, split on ":": user name and shell
cut -c1-15 tests/fixtures/secure.log   # characters 1 to 15: the syslog timestamp
tr 'a-z' 'A-Z' <<< "web-01"         # translate characters: WEB-01
tr -s ' ' < file                    # squeeze repeated spaces into one (handy before cut -d' ')
tr -d '\r' < windows.txt > unix.txt # delete carriage returns from Windows line endings
paste -sd, list.txt                 # join all lines with commas
column -t -s: /etc/group | head     # align columns into a table
```

`cut` only splits on a single character. When columns are separated by variable runs of spaces (as in `ps` or `df` output), use `awk`.

## sort, uniq, wc

```sh
sort names.txt                      # alphabetical
sort -n numbers.txt                 # numeric (otherwise "10" sorts before "9")
sort -rn                            # numeric, largest first
sort -h                             # human sizes: 2K < 1M < 3G (pairs with du -h)
sort -t: -k3,3n /etc/passwd         # by field 3 (UID), numerically, splitting on ":"
sort -u                             # sort and remove duplicates
uniq -c                             # count adjacent duplicates (sort first!)
wc -l file                          # count lines
```

`sort | uniq -c | sort -rn` is the most useful pipeline in operations: **"how many of each, most common first."**

```sh
grep -oE 'from ([0-9]{1,3}\.){3}[0-9]{1,3}' tests/fixtures/secure.log | sort | uniq -c | sort -rn
#       4 from 203.0.113.9
#       3 from 198.51.100.4
#       3 from 192.0.2.10
```

## sed

`sed` reads input line by line and applies commands to each. The one you'll use most is substitute: `s/PATTERN/REPLACEMENT/FLAGS`.

```sh
sed 's/http:/https:/' file                  # first match on each line
sed 's/http:/https:/g' file                 # g: every match
sed -E 's/(user=)[^ ]+/\1***/g' app.log     # mask values; \1 is the captured "user="
sed -n '10,20p' file                        # print only lines 10 to 20 (-n: no automatic printing)
sed -n '/^\[mysqld\]/,/^\[/p' my.cnf        # print from one pattern to the next
sed '/^#/d; /^$/d' file                     # delete comment lines and blank lines
sed '1i # Managed by Ansible' file          # insert a line before line 1
sed '$a\export PATH=$PATH:/opt/bin' file    # append after the last line
sed -i.bak 's/^Listen 80$/Listen 8080/' httpd.conf   # -i: edit in place, keeping httpd.conf.bak
```

**`sed -i` edits files in place with no undo.** Run without `-i` first to see the result, and always use a backup suffix on files you care about. Note that BSD sed (macOS) requires an argument after `-i`; `-i.bak` works on both.

## awk

`awk` splits each line into fields (`$1`, `$2`, ... and `$0` for the whole line, `NF` for the number of fields), and runs `pattern { action }` rules on each line.

```sh
awk '{ print $1 }' tests/fixtures/access.log                 # first field: client IP
awk -F: '{ print $1, $3 }' /etc/passwd                       # -F sets the separator: user and UID
awk -F: '$3 >= 1000 { print $1 }' /etc/passwd                # only regular users (UID 1000 and up on both families)
awk '$9 >= 500' tests/fixtures/access.log                    # lines where field 9 (status) is 500 or more
awk '{ print $NF }' file                                     # the last field
awk 'NR > 1' data.csv                                        # skip the header line (NR: line number)
awk '{ sum += $10 } END { print sum / 1024, "KB" }' tests/fixtures/access.log   # total bytes sent
awk '{ count[$9]++ } END { for (s in count) print s, count[s] }' tests/fixtures/access.log   # count per status
awk 'length > 200' app.log                                   # lines longer than 200 characters
awk '!seen[$0]++' file                                       # remove duplicate lines, keeping order
```

The last one deserves a breakdown, because it shows how awk thinks:

| Part | Means |
|---|---|
| `seen[$0]` | An associative array entry keyed by the whole line; starts as 0 (false) |
| `seen[$0]++` | Use the current value, then add one. First time: 0, later: 1, 2... |
| `!` | Negate: true only when the value was 0, the first time this line appears |
| (no action) | A pattern with no action prints the line |

Use `printf` for formatted output: `awk -F: '{ printf "%-20s %6d\n", $1, $3 }' /etc/passwd`.

## find

```sh
find /var/log -name '*.log' -mtime +30              # .log files modified more than 30 days ago
find / -xdev -type f -size +500M 2>/dev/null        # files over 500 MB on this filesystem (-xdev: don't cross mounts)
find /etc -newer /etc/hostname -type f              # changed more recently than another file
find /srv -type d -perm -o+w                        # world-writable directories
find /home -nouser                                  # files whose owner no longer exists
find . -name '*.tmp' -delete                        # delete matches (run without -delete first!)
find . -type f -name '*.sh' -exec shellcheck {} +   # run a command on all matches at once
```

`-exec cmd {} \;` runs the command once per file; `-exec cmd {} +` passes many files per run, which is much faster.

## xargs

`xargs` turns lines of input into arguments for a command:

```sh
cat hosts.txt | xargs -I{} ssh {} uptime              # -I{}: one command per line, {} is the line
find . -name '*.log' -print0 | xargs -0 gzip          # -print0 / -0: NUL-separated, safe for names with spaces
xargs -P4 -n1 curl -sO < urls.txt                     # -P4: four at a time in parallel; -n1: one URL per curl
```

Always pair `find -print0` with `xargs -0` when file names might contain spaces or newlines.

## jq

Most cloud CLIs, APIs, and modern tools speak JSON. `jq` is to JSON what awk is to text. Install with `dnf install jq` or `apt install jq`.

```sh
echo '{"name":"web-01","tags":{"env":"prod"},"ips":["10.0.0.5","10.0.0.6"]}' > host.json

jq . host.json                          # pretty-print
jq -r .name host.json                   # -r: raw string, no quotes: web-01
jq -r '.tags.env' host.json             # nested: prod
jq -r '.ips[]' host.json                # each array element on its own line
jq -r '.ips | length' host.json         # 2
jq '{host: .name, env: .tags.env}' host.json         # build a new object
jq -c '.[] | select(.status == "running")' list.json # filter an array; -c: one object per line
jq -r '.[] | [.name, .status] | @tsv' list.json      # to tab-separated columns
jq --arg env prod '.[] | select(.tags.env == $env)' list.json   # pass a shell value in safely
```

For YAML, `yq` has the same syntax. The AWS and Azure CLIs also have `--query` (JMESPath) built in, covered in the [AWS](../aws/README.md#make-output-usable) and [Azure](../azure/README.md#make-output-usable) guides.

---

## Putting it together

Each of these is broken down part by part in [Complex commands](07-complex-commands.md):

```sh
# Requests per status code from an access log, most common first
awk '{ print $9 }' tests/fixtures/access.log | sort | uniq -c | sort -rn

# The ten biggest directories under /var, human-readable
sudo du -xh --max-depth=2 /var 2>/dev/null | sort -rh | head -10

# Which processes hold deleted files open (disk space that df counts but du can't find)
sudo lsof -nP +L1 2>/dev/null | awk 'NR > 1 { print $1, $2, $7, $NF }' | sort -k3 -rn | head

# Users who can log in, with their shells
awk -F: '$7 !~ /(nologin|false)$/ { print $1 ": " $7 }' /etc/passwd
```
