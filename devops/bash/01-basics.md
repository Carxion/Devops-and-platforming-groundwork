# Basics

[← Bash 101](README.md)

Enough of the shell to work on any Linux server: moving around, files, permissions, redirection and pipes, variables and quoting, and the keyboard shortcuts that save hours. Everything here behaves the same on RHEL and Ubuntu; the few differences are called out.

## Getting help

```sh
man ls            # the manual page; / to search, n for next match, q to quit
ls --help         # short usage for most GNU tools
help cd           # help for Bash built-ins (cd, read, test, for...)
type ls           # what a name is: alias, function, built-in, or file
apropos firewall  # search man page descriptions (or: man -k firewall)
```

If `man` says no manual entry on a minimal server or container: `dnf install man-db man-pages` (RHEL) or `apt install man-db` and run `unminimize` (Ubuntu minimal images strip docs).

## Moving around

```sh
pwd                  # print working directory
cd /var/log          # absolute path: starts at /
cd ../lib            # relative path: .. is the parent, . is here
cd ~   # or just cd  # your home directory
cd -                 # back to the previous directory
ls -lah              # long format, all files (including .hidden), human sizes
ls -lt | head        # newest first
ls -ld /etc          # the directory itself, not its contents
tree -L 2 /etc/ssh   # a tree two levels deep (install the tree package)
```

The filesystem layout is the same on both families:

| Path | Holds |
|---|---|
| `/etc` | System configuration (text files) |
| `/var/log` | Logs: `messages` and `secure` on RHEL, `syslog` and `auth.log` on Ubuntu; plus the journal |
| `/var/lib` | Application state: databases, Docker, package metadata |
| `/home`, `/root` | User homes, and root's home |
| `/usr/bin`, `/usr/sbin` | Installed programs (`/bin` and `/sbin` are symlinks to these on current releases) |
| `/usr/local` | Software installed by hand, outside the package manager |
| `/opt` | Self-contained third-party applications |
| `/tmp` | Temporary files, cleared at boot (and often a RAM-backed tmpfs) |
| `/proc`, `/sys` | Kernel views of processes and hardware, not real files |
| `/dev` | Devices: disks (`/dev/sda`, `/dev/nvme0n1`), `/dev/null` |

## Files

```sh
cat /etc/os-release           # print a file
less /var/log/messages        # page through: space, b, /search, G end, g start, F follow, q quit
head -n 20 file; tail -n 50 file
tail -f /var/log/secure       # follow new lines as they're written (Ctrl-C to stop)
tail -F app.log               # follow even across log rotation

cp -a src/ dest/              # -a: recursive, keep permissions, owners, times, links
mv old new                    # move or rename
rm -i file                    # -i: ask first. There is no undo and no trash.
rm -r dir                     # recursive. Read the command twice before Enter.
mkdir -p a/b/c                # create parents as needed, no error if it exists
touch file                    # create empty, or update the timestamp
ln -s /opt/app/current app    # symbolic link (a pointer to a path)
stat file                     # size, permissions, owner, and all timestamps
file mystery.bin              # what kind of content it is
du -sh /var/log/*             # size of each item
```

### Editing

On a server, you'll use `vi` (always installed) or `nano` (easier, usually installed on Ubuntu, `dnf install nano` on RHEL). The minimum vi:

| Keys | Does |
|---|---|
| `i` | Insert mode: type text |
| `Esc` | Back to command mode |
| `:w` | Save |
| `:q` | Quit; `:q!` to quit without saving; `:wq` to save and quit |
| `/text` then `n` | Search, then next match |
| `dd`, `u` | Delete line, undo |

Before editing anything in `/etc`, copy it: `sudo cp -a /etc/ssh/sshd_config{,.bak}` (the braces expand to `/etc/ssh/sshd_config /etc/ssh/sshd_config.bak`).

## Permissions

```text
-rw-r----- 1 deploy webapps 4096 Oct 13 08:00 app.conf
│└┬┘└┬┘└┬┘   └─┬──┘ └──┬──┘
│ │  │  │      owner  group
│ │  │  └ others: no access
│ │  └ group: read
│ └ owner: read, write
└ type: - file, d directory, l link
```

| Permission | On a file | On a directory |
|---|---|---|
| `r` (4) | Read the contents | List the names inside |
| `w` (2) | Change the contents | Create, delete, and rename entries inside |
| `x` (1) | Run it as a program | Enter it (`cd`) and reach files inside |

```sh
chmod 640 app.conf            # numeric: owner rw (4+2), group r (4), others none
chmod u+x deploy.sh           # symbolic: add execute for the owner
chmod -R g+rX /srv/www        # capital X: execute only on directories (and already-executable files)
chown deploy:webapps app.conf # owner and group
id deploy                     # a user's UID, primary group, and other groups
umask                         # default permissions removed from new files (usually 0022)
```

Common modes: `600` private files (SSH keys), `644` readable config, `640` config with secrets readable by a group, `700` private directories (`~/.ssh`), `755` programs and public directories.

Special bits you'll see: **setuid** on `/usr/bin/passwd` (`-rwsr-xr-x`, runs as its owner), **setgid** on shared directories (new files inherit the group), and the **sticky bit** on `/tmp` (`drwxrwxrwt`, only owners can delete their files).

**sudo** runs one command as root: `sudo systemctl restart nginx`. `sudo -i` opens a root shell; prefer single commands, which are logged one by one. Admins are the `wheel` group on RHEL and the `sudo` group on Ubuntu.

On RHEL, **SELinux** adds another layer of permission checks on top of these: a file can be `644` and still unreadable to a service. See [RHEL and Ubuntu](05-rhel-and-ubuntu.md#selinux-and-apparmor).

## Redirection and pipes

Every process has three streams: standard input (0), standard output (1), and standard error (2).

| Syntax | Does |
|---|---|
| `cmd > file` | Write stdout to a file, replacing it |
| `cmd >> file` | Append stdout |
| `cmd 2> errors.log` | Write stderr to a file |
| `cmd > out.log 2>&1` | Both to the same file. Order matters: `2>&1` means "stderr goes where stdout goes now" |
| `cmd &> out.log` | Bash shorthand for the same |
| `cmd 2>/dev/null` | Discard errors |
| `cmd < file` | Read stdin from a file |
| `cmd1 \| cmd2` | Pipe: stdout of cmd1 becomes stdin of cmd2 |
| `cmd \| tee file` | Show output and save it too; `sudo tee` writes files as root |

```sh
# sudo applies to the command, not the redirect, so this fails:
sudo echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/90-forward.conf    # Permission denied
# Use tee, which sudo does apply to:
echo "net.ipv4.ip_forward = 1" | sudo tee /etc/sysctl.d/90-forward.conf

# Here-document: multi-line input, often to write a file
cat <<'EOF' | sudo tee /etc/motd
Managed by the platform team. Changes here are overwritten.
EOF

# Here-string: one line of input
grep -c ':' <<< "a:b:c"
```

Quote the here-document marker (`<<'EOF'`) to stop `$variables` and `$(commands)` inside from expanding; leave it unquoted when you want them to.

## Exit codes and chaining

Every command returns an exit code: 0 is success, anything else is failure. `$?` holds the last one.

```sh
grep -q root /etc/passwd; echo $?     # 0: found
grep -q nobody-here /etc/passwd; echo $?  # 1: not found
mkdir -p /srv/app && cd /srv/app      # && runs the second only if the first succeeded
ping -c1 db.internal || echo "db unreachable"   # || runs the second only if the first failed
```

## Variables and quoting

```sh
name="web-01"                  # no spaces around =
echo "Host: $name"             # double quotes: variables expand
echo 'Host: $name'             # single quotes: everything is literal
echo "Host: ${name}-backup"    # braces separate the name from following text
today="$(date +%F)"            # command substitution: the command's output
count=$((3 * 4 + 1))           # arithmetic
export APP_ENV=prod            # make it visible to child processes
```

**Quote every variable expansion: `"$var"`.** Unquoted, the value is split on spaces and expanded as a glob. With `file="my report.txt"`, `rm $file` tries to delete `my` and `report.txt`. ShellCheck catches this.

### Parameter expansion

Bash can transform a variable's value without calling another program:

| Expression | With `f=/var/log/nginx/access.log.1` | Means |
|---|---|---|
| `${f##*/}` | `access.log.1` | Remove the longest prefix matching `*/` (like `basename`) |
| `${f%/*}` | `/var/log/nginx` | Remove the shortest suffix matching `/*` (like `dirname`) |
| `${f%.*}` | `/var/log/nginx/access.log` | Remove the last extension |
| `${f%%.*}` | `/var/log/nginx/access` | Remove everything from the first dot |
| `${f/log/LOG}` | `/var/LOG/nginx/access.log.1` | Replace the first match |
| `${f//log/LOG}` | `/var/LOG/nginx/access.LOG.1` | Replace every match |
| `${#f}` | `28` | Length |
| `${f:0:8}` | `/var/log` | Substring: offset 0, length 8 |
| `${v:-default}` | | `default` if `v` is unset or empty |
| `${v:=default}` | | Same, and also assign it |
| `${v:?message}` | | Exit with `message` if `v` is unset or empty |
| `${v^^}`, `${v,,}` | | Upper case, lower case |

### Globbing and brace expansion

```sh
ls *.log              # * any characters
ls app-?.log          # ? exactly one character
ls app-[0-9].log      # one character from the set
shopt -s globstar; ls **/*.conf   # ** recurses into subdirectories
shopt -s nullglob     # a glob with no matches expands to nothing, not to itself

echo {a,b,c}.txt      # a.txt b.txt c.txt
mkdir -p env/{dev,test,prod}/config
echo {01..05}         # 01 02 03 04 05
cp app.conf{,.bak}    # app.conf app.conf.bak
```

Globs aren't regular expressions: `*` here means "any characters", while in a regex it means "the previous item, any number of times".

## Conditions and loops

```sh
if [[ -f /etc/redhat-release ]]; then
  echo "RHEL family"
elif [[ -f /etc/debian_version ]]; then
  echo "Debian family"
fi

for host in web-01 web-02 web-03; do
  ssh "$host" uptime
done

while read -r user _ uid _; do
  echo "$user has uid $uid"
done < <(awk -F: '{ print $1, "x", $3 }' /etc/passwd)

case "$1" in
  start | stop) systemctl "$1" app ;;
  *) echo "usage: $0 start|stop" ;;
esac
```

| Test (inside `[[ ]]`) | True when |
|---|---|
| `-f path` / `-d path` / `-e path` | It's a file / a directory / exists at all |
| `-r`, `-w`, `-x` path | Readable, writable, executable by you |
| `-s path` | Exists and isn't empty |
| `-z "$v"` / `-n "$v"` | The string is empty / not empty |
| `"$a" == "$b"`, `!=` | Strings equal or not; the right side can be a glob: `[[ $f == *.log ]]` |
| `"$s" =~ regex` | Matches an ERE ([Regular expressions](03-regex.md#bash-validate-input)) |
| `$a -eq $b`, `-ne`, `-lt`, `-le`, `-gt`, `-ge` | Integer comparisons (or use `(( a < b ))`) |
| `a && b`, `a \|\| b`, `! a` | And, or, not |

Use `[[ ]]` in Bash scripts; it's safer than the older `[ ]` (no word splitting inside).

## Keyboard shortcuts

| Keys | Does |
|---|---|
| `Tab` (twice) | Complete commands, paths, and (with bash-completion installed) options |
| `Ctrl-R` | Search history backwards; again for older matches |
| `Ctrl-A` / `Ctrl-E` | Start / end of line |
| `Alt-B` / `Alt-F` | Back / forward one word |
| `Ctrl-W` / `Ctrl-U` / `Ctrl-K` | Delete word before / to start / to end |
| `Alt-.` | Insert the last argument of the previous command (repeat for earlier ones) |
| `!!` | The previous command: `sudo !!` reruns it with sudo |
| `Ctrl-C` | Interrupt the running command |
| `Ctrl-D` | End of input; exits the shell at an empty prompt |
| `Ctrl-L` | Clear the screen |

## Jobs and long-running work

```sh
long-task &            # run in the background
jobs                   # list background jobs
fg %1                  # bring job 1 to the foreground
# Ctrl-Z suspends the foreground job; bg resumes it in the background
nohup long-task > task.log 2>&1 &   # keeps running after you log out
```

For anything that must survive a dropped SSH connection, use **tmux** (`dnf install tmux` or `apt install tmux`): `tmux new -s work` to start, `Ctrl-B d` to detach, `tmux attach -t work` to return. For anything that must run reliably or on a schedule, make it a systemd service or timer ([Writing scripts](04-scripting.md#scheduling)).

## Your shell environment

| File | Read by | Use for |
|---|---|---|
| `~/.bashrc` | Every interactive shell | Aliases, functions, prompt |
| `~/.bash_profile` (RHEL) or `~/.profile` (Ubuntu) | Login shells (SSH logins) | Environment variables; both distributions' defaults source `~/.bashrc` from here |
| `/etc/bashrc` (RHEL), `/etc/bash.bashrc` (Ubuntu) | Everyone | System-wide settings |
| `/etc/profile.d/*.sh` | Every login shell | System-wide environment, added by packages or you |

```sh
alias ll='ls -lah'
export PATH="$HOME/bin:$PATH"     # prepend your own bin directory
PS1='\u@\h:\w\$ '                 # prompt: user@host:dir$
mkcd() { mkdir -p "$1" && cd "$1"; }   # a function, for anything an alias can't do
```

Put the hostname and environment in the prompt on servers (for example, red for production). Knowing where you are prevents more incidents than any tool.
