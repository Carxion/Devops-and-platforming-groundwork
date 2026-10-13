# Regular expressions

[← Bash 101](README.md)

A regular expression (regex) is a pattern that matches text. On Linux you'll use them in `grep` to find lines, in `sed` to change them, in `awk` to pick fields, and in Bash's `[[ =~ ]]` to validate input. This page explains the syntax from the ground up, then breaks down the patterns that come up again and again in operations work.

Every pattern in the [pattern library](#pattern-library) is tested against strings it must and mustn't match, in [tests/regex.bats](tests/regex.bats). If you change a pattern here, change the test too.

---

## Three flavors

The same idea, with three dialects. Most confusion with regex on Linux comes from using one dialect's syntax in a tool that speaks another.

| Flavor | Used by | Notes |
|---|---|---|
| **BRE** (basic) | `grep`, `sed` (default) | `?`, `+`, `{`, `\|`, `(` are literal characters unless backslashed: `\+`, `\{2\}`, `\(group\)` |
| **ERE** (extended) | `grep -E`, `sed -E`, `awk`, Bash `[[ =~ ]]` | The metacharacters work without backslashes. **Use this by default.** |
| **PCRE** (Perl-compatible) | `grep -P`, `perl`, Python, most programming languages | Adds `\d`, `\w`, `\s`, lookarounds, lazy quantifiers. `grep -P` is GNU grep only. |

The same match in each:

```sh
grep    'error\(s\)\{0,1\}'  app.log    # BRE
grep -E 'errors?'          app.log    # ERE: the same thing, readable
grep -P 'errors?'          app.log    # PCRE: also the same here
```

**`\d` doesn't exist in BRE or ERE.** `grep -E '\d+'` matches the letter `d`, not digits. Use `[0-9]` or `[[:digit:]]`. GNU grep and sed do accept `\w`, `\s`, and `\b` as extensions, but other tools (and BSD grep on macOS) may not.

---

## The building blocks

### Characters and classes

| Syntax | Matches | Example |
|---|---|---|
| `a` | The character itself | `cat` matches "cat" in "concatenate" |
| `.` | Any one character except newline | `c.t` matches "cat", "cot", "c9t" |
| `[abc]` | One of the listed characters | `gr[ae]y` matches "gray" and "grey" |
| `[a-z]` | One character in the range | `[0-9]` is one digit |
| `[^abc]` | One character *not* listed | `[^ ]+` is a run of non-spaces: one "word" in a log line |
| `\.` | A literal dot (escape any metacharacter) | `example\.com` doesn't match "exampleXcom" |

### POSIX character classes

Inside brackets, these named classes are portable and locale-aware. Prefer them to ranges like `[a-z]`, which can include unexpected characters in some locales.

| Class | Same as (in the C locale) |
|---|---|
| `[[:digit:]]` | `[0-9]` |
| `[[:alpha:]]` | `[A-Za-z]` |
| `[[:alnum:]]` | `[A-Za-z0-9]` |
| `[[:upper:]]`, `[[:lower:]]` | `[A-Z]`, `[a-z]` |
| `[[:space:]]` | space, tab, newline, carriage return, form feed, vertical tab |
| `[[:blank:]]` | space and tab only |
| `[[:punct:]]` | punctuation |
| `[[:xdigit:]]` | `[0-9A-Fa-f]` |

The double brackets matter: `[[:digit:]]` is a bracket expression containing the class `[:digit:]`. You can combine them: `[[:alnum:]_-]` is a letter, digit, underscore, or hyphen.

### Quantifiers: how many

| Syntax | Means | Example |
|---|---|---|
| `*` | Zero or more | `ab*c` matches "ac", "abc", "abbbc" |
| `+` | One or more | `[0-9]+` is a whole number |
| `?` | Zero or one (optional) | `https?` matches "http" and "https" |
| `{3}` | Exactly 3 | `[0-9]{3}` is three digits |
| `{2,4}` | 2 to 4 | `[a-z]{2,4}` |
| `{2,}` | 2 or more | |

Quantifiers are **greedy**: they take as much as they can while still letting the whole pattern match. `".*"` on `say "hi" and "bye"` matches `"hi" and "bye"`, from the first quote to the last. In PCRE, add `?` to make one lazy (`".*?"` matches `"hi"`); in ERE, use a negated class instead (`"[^"]*"`), which is also faster.

### Anchors and boundaries

| Syntax | Matches the position |
|---|---|
| `^` | Start of the line |
| `$` | End of the line |
| `\b` | A word boundary (GNU grep and sed, PCRE) |
| `\<`, `\>` | Start and end of a word (GNU grep and sed) |

Anchors are what turn "contains" into "is". `[0-9]+` matches any line containing a digit; `^[0-9]+$` matches only lines that are entirely digits. **Validation patterns always need both anchors.**

### Groups and alternation

| Syntax | Means |
|---|---|
| `(abc)` | Group: apply a quantifier to several characters, and capture what matched |
| `a\|b` | Alternation: either side |
| `\1`, `\2` | Back-reference to captured group 1, 2 (in `sed` replacements and BRE patterns) |
| `(?:abc)` | Non-capturing group (PCRE only) |

`(ERROR|WARN)` matches either word; `(ab)+` matches "ab", "abab"; `^(GET|POST)[[:space:]]` matches lines starting with either method.

### Lookarounds (PCRE only)

Lookarounds check what's before or after a position without including it in the match. With `grep -oP`, they're the cleanest way to extract a value.

| Syntax | Means | Example |
|---|---|---|
| `(?=x)` | Followed by x | `\d+(?=ms)` gets "250" from "took 250ms" |
| `(?!x)` | Not followed by x | |
| `(?<=x)` | Preceded by x | `(?<=user=)[^ ]+` gets "alice" from "user=alice id=7" |
| `(?<!x)` | Not preceded by x | |
| `\K` | Reset the match start (like a variable-length lookbehind) | `user=\K[^ ]+` does the same as the lookbehind above |

---

## Regex in each tool

### grep: find lines

```sh
grep -E 'ERROR|FATAL' app.log              # lines with either word
grep -Ei 'error' app.log                   # -i: ignore case
grep -Ev '^[[:space:]]*(#|$)' sshd_config  # -v: lines NOT matching (here: drop comments and blanks)
grep -Eo '[0-9]+ms' app.log                # -o: print only the matched part, one per line
grep -Ec 'Failed password' /var/log/secure # -c: count matching lines
grep -Erl 'TODO' src/                      # -r recursive, -l only file names
grep -Ew 'root' /etc/passwd                # -w: whole words only
grep -E -A2 -B1 'panic' app.log            # 2 lines after, 1 before each match
grep -oP '(?<=user=)[^ ]+' app.log         # PCRE lookbehind: just the value
```

### sed: change text

`sed 's/PATTERN/REPLACEMENT/FLAGS'` substitutes. Use `-E` for ERE. `&` in the replacement is the whole match; `\1` is the first group.

```sh
sed -E 's/[0-9]{4}-[0-9]{2}-[0-9]{2}/<date>/g' app.log            # g: every match on the line, not just the first
sed -E 's/(user=)[^ ]+/\1REDACTED/' app.log                         # keep the key, replace the value
sed -E 's/^([^,]*),([^,]*)/\2,\1/' data.csv                         # swap the first two CSV columns
sed -n -E '/BEGIN CERTIFICATE/,/END CERTIFICATE/p' bundle.pem       # print a range of lines between two patterns
sed -E '/^[[:space:]]*(#|$)/d' config.conf                          # delete comments and blank lines
sed -i.bak -E 's/^#?(PermitRootLogin) .*/\1 no/' /etc/ssh/sshd_config  # edit in place, keeping a .bak copy
```

Any character can be the delimiter, which saves escaping slashes in paths: `sed 's#/usr/local#/opt#g'`.

### awk: match fields

`awk` matches regexes against whole lines (`/pattern/`) or specific fields (`$3 ~ /pattern/`):

```sh
awk '/ERROR/ { n++ } END { print n }' app.log                 # count lines matching
awk '$9 ~ /^5[0-9][0-9]$/' access.log                         # field 9 (status in common log format) is a 5xx
awk -F: '$7 !~ /(nologin|false)$/ { print $1 }' /etc/passwd   # users with a real login shell
awk 'match($0, /took [0-9]+ms/) { print substr($0, RSTART + 5, RLENGTH - 7) }' app.log  # extract the number
```

### Bash: validate input

`[[ string =~ regex ]]` uses ERE. Captured groups land in the `BASH_REMATCH` array. **Don't quote the regex**: a quoted right-hand side is matched literally. Store complex patterns in a variable instead:

```sh
re='^([A-Za-z_][A-Za-z0-9_]*)=(.*)$'
line='DB_HOST=db.internal'
if [[ "$line" =~ $re ]]; then
  echo "key=${BASH_REMATCH[1]} value=${BASH_REMATCH[2]}"   # key=DB_HOST value=db.internal
fi
```

The scripts in this folder use this for every argument: [wait-for-port.sh](scripts/wait-for-port.sh) parses `HOST:PORT`, [create-admin-user.sh](scripts/create-admin-user.sh) checks user names and key formats, and [bootstrap-server.sh](scripts/bootstrap-server.sh) checks hostnames.

---

## Pattern library

Each pattern is ERE unless marked PCRE, and tested in [tests/regex.bats](tests/regex.bats). For validation, wrap them in `^...$`.

### IPv4 address

Loose, for finding addresses in logs (also matches impossible ones like `999.1.1.1`):

```text
([0-9]{1,3}\.){3}[0-9]{1,3}
```

| Part | Means |
|---|---|
| `[0-9]{1,3}` | One to three digits |
| `\.` | A literal dot |
| `( ... ){3}` | That pair, three times: "203." "0." "113." |
| `[0-9]{1,3}` | The last group of digits, with no dot after it |

Strict, for validation (each part 0 to 255):

```text
((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])
```

| Alternative | Matches |
|---|---|
| `25[0-5]` | 250 to 255 |
| `2[0-4][0-9]` | 200 to 249 |
| `1[0-9]{2}` | 100 to 199 |
| `[1-9]?[0-9]` | 0 to 99, with no leading zero |

The order of alternatives matters for extraction: put the longest first, or `[1-9]?[0-9]` could match just the "25" of "255".

### IPv4 CIDR block

```text
^((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])/(3[0-2]|[12]?[0-9])$
```

The strict address, then `/` and a prefix length of 0 to 32: `3[0-2]` is 30 to 32, and `[12]?[0-9]` is 0 to 29.

### ISO 8601 date

```text
[0-9]{4}-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])
```

Four-digit year, month 01 to 12 (`0[1-9]` or `1[0-2]`), day 01 to 31 (`0[1-9]`, `[12][0-9]`, or `3[01]`). It accepts February 31; a regex checks shape, not calendars. Use `date -d "$value"` when the date must be real.

### Timestamp in a log line

```text
[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?(Z|[+-][0-9]{2}:?[0-9]{2})?
```

Date, then `T` or a space, then the time, optional fractional seconds `(\.[0-9]+)?`, and an optional zone: `Z` or an offset like `+05:30` or `-0800`.

### Email address (practical)

```text
[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}
```

| Part | Means |
|---|---|
| `[A-Za-z0-9._%+-]+` | The local part: letters, digits, and `. _ % + -` |
| `@` | Literally |
| `[A-Za-z0-9.-]+` | The domain, which may contain dots |
| `\.[A-Za-z]{2,}` | A dot and a top-level domain of two or more letters |

This is good for finding and rough-checking addresses. Fully validating email addresses with a regex isn't practical; send a confirmation email instead.

### Semantic version

```text
^v?(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$
```

An optional `v`, then MAJOR.MINOR.PATCH where each is `0` or a number without leading zeros (`0|[1-9][0-9]*`), an optional pre-release (`-rc.1`), and optional build metadata (`+build.5`). This is a simplified form of the official pattern at [semver.org](https://semver.org/).

### UUID

```text
[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}
```

Eight hex digits, three groups of four (each followed by a hyphen), and twelve: the 8-4-4-4-12 layout.

### Linux user name

```text
^[a-z_][a-z0-9_-]{0,31}$
```

A lowercase letter or underscore first, then up to 31 lowercase letters, digits, underscores, or hyphens. That's the conservative default `useradd` enforces on both RHEL and Ubuntu.

### Hostname (RFC 1123)

```text
^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*$
```

| Part | Means |
|---|---|
| `[A-Za-z0-9]` | A label starts with a letter or digit |
| `([A-Za-z0-9-]{0,61}[A-Za-z0-9])?` | Optionally up to 61 more characters including hyphens, ending in a letter or digit: labels are at most 63 characters and can't end in a hyphen |
| `(\. ... )*` | Any number of further dot-separated labels |

### Port number in HOST:PORT

```text
^(\[[0-9A-Fa-f:]+\]|[A-Za-z0-9.-]+):([0-9]{1,5})$
```

Group 1 is either a bracketed IPv6 address (`\[[0-9A-Fa-f:]+\]`) or a name or IPv4 address; group 2 is the port. The range check (1 to 65535) is done with arithmetic afterward, which is far clearer than a regex for numeric ranges.

### Container image reference

```text
^[a-z0-9]+([._/-][a-z0-9]+)*(:[0-9]+)?(/[a-z0-9]+([._-][a-z0-9]+)*)*(:[A-Za-z0-9_][A-Za-z0-9_.-]{0,127})?(@sha256:[a-f0-9]{64})?$
```

A registry and repository path of lowercase parts separated by `.`, `_`, `-`, or `/`, an optional registry port, an optional tag (up to 128 characters, not starting with `.` or `-`), and an optional digest. Use it to require digests in a policy check: change the final `?` after the digest group to make it mandatory.

### AWS access key ID (for secret scanning)

```text
\b(AKIA|ASIA)[A-Z0-9]{16}\b
```

Long-lived keys start with `AKIA`, temporary ones with `ASIA`, followed by 16 uppercase letters and digits. `\b` (GNU grep) stops it matching inside a longer string. A quick check of a repository: `grep -rEn '\b(AKIA|ASIA)[A-Z0-9]{16}\b' .`. Real secret scanners (gitleaks, trufflehog) combine hundreds of patterns like this with entropy checks.

### HTTP status class

```text
^[45][0-9]{2}$
```

A three-digit code starting with 4 or 5: client and server errors. `^5[0-9]{2}$` is server errors only.

### Log level

```text
\b(FATAL|ERROR|WARN(ING)?)\b
```

`WARN(ING)?` matches "WARN" and "WARNING". Combine with `-c` to count, or with `-o` and `sort | uniq -c` to count per level.

### Comment or blank line

```text
^[[:space:]]*(#|$)
```

Optional leading whitespace, then either `#` or the end of the line. With `grep -Ev` it shows the settings that are actually in effect in a config file.

### A config setting, commented out or not

```sh
sed -E 's/^[[:space:]]*#?[[:space:]]*(PasswordAuthentication)[[:space:]].*/\1 no/' sshd_config
```

| Part | Means |
|---|---|
| `^[[:space:]]*` | Optional indentation |
| `#?` | An optional comment marker, so this also enables a commented-out default |
| `[[:space:]]*` | Optional space after the `#` |
| `(PasswordAuthentication)` | The key, captured as group 1 |
| `[[:space:]].*` | Whitespace, then the old value (everything to the end of the line) |
| `\1 no` | Replacement: the key and the new value |

For SSH specifically, prefer a drop-in file as [harden-ssh.sh](scripts/harden-ssh.sh) does; this pattern is for files without drop-in support.

### Extract a value with PCRE

```sh
grep -oP 'duration=\K[0-9.]+' app.log      # "duration=0.250s" -> 0.250
grep -oP '(?<=trace_id=)[0-9a-f]{32}' app.log
grep -oP '"status":\s*\K[0-9]+' app.json   # a value from JSON lines (but use jq for real JSON)
```

---

## Habits

- **Test with sample lines first:** `printf '%s\n' 'good line' 'bad line' | grep -E 'pattern'`. Or use [regex101.com](https://regex101.com/) (choose the PCRE flavor; most ERE behaves the same).
- **Anchor validation patterns** with `^` and `$`. Without them, `[0-9]+` "validates" `abc1def`.
- **Escape the dot** in domain names and versions: `example\.com`, `1\.2\.3`.
- **Prefer negated classes to `.*`** between delimiters: `"[^"]*"`, `\[[^]]*\]`. They can't overrun the delimiter, and they're faster.
- **Don't parse structured formats with regex** when a parser exists: `jq` for JSON, `yq` for YAML, `xmllint` for XML, `awk -F,` (or a CSV tool) for simple CSV.
- **Keep them readable.** A regex nobody understands is a regex nobody dares to fix. Break long patterns into named variables in scripts, and comment them, as the scripts in this folder do.
- **Set the locale for byte-exact matching** on unusual input: `LC_ALL=C grep ...` is also much faster on large files.
