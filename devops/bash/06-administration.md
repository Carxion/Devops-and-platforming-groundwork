# Administration and troubleshooting

[← Bash 101](README.md)

What to run when a server is slow, full, unreachable, or a service won't start, in the order that finds the answer fastest. Commands work on both RHEL and Ubuntu unless a row says otherwise. Many tools come from packages worth installing on every server: `sysstat` (iostat, mpstat, pidstat, sar), `iotop`, `lsof`, `strace`, `tcpdump`, `mtr`, and `bind-utils` (RHEL) or `dnsutils` (Ubuntu) for `dig`.

| Problem | Go to |
|---|---|
| Something's wrong, not sure what | [The first five minutes](#the-first-five-minutes) |
| Slow, high load | [CPU and load](#cpu-and-load) |
| Out of memory, processes killed | [Memory](#memory) |
| Disk full | [Disk full](#disk-full) |
| Disk slow | [Disk I/O](#disk-io) |
| Can't connect | [Network](#network) |
| Service won't start | [Services](#services) |
| Can't SSH in | [SSH](#ssh) |
| Time is wrong | [Time](#time) |

---

## The first five minutes

Run these in order on any misbehaving host. Each takes a second, and together they answer most "what's wrong" questions. [system-report.sh](scripts/system-report.sh) runs them all and saves the output for a ticket.

```sh
uptime                               # how long up, and load averages (1, 5, 15 minutes)
dmesg -T | tail -20                  # recent kernel messages: OOM kills, disk errors, hardware
journalctl -p err -b --no-pager | tail -30   # errors since boot, from everything
systemctl --failed                   # units that failed
free -h                              # memory: look at "available", not "free"
df -h; df -i                         # space and inodes per filesystem
top -o %CPU                          # what's busy right now (q to quit; M sorts by memory)
ss -tulpn                            # what's listening, and which process owns it
last -n 10; who                      # recent logins, and who's on now
```

Then ask: **what changed?** Package installs (`dnf history`, `/var/log/apt/history.log`), config changes (`find /etc -mmin -120 -type f`), deployments, and reboots (`last reboot`, `journalctl --list-boots`).

## CPU and load

**Load average** is the number of processes running or waiting to run, including those waiting on disk. Compare it to the CPU count (`nproc`): a load of 8 is busy on 4 CPUs and idle on 32.

```sh
nproc; uptime
top -o %CPU                       # press 1 for per-CPU lines
mpstat -P ALL 1 5                 # per-CPU use every second, five times (sysstat)
pidstat 1 5                       # per-process CPU over time (sysstat)
ps -eo pid,user,%cpu,%mem,etime,cmd --sort=-%cpu | head -15
```

Read the CPU line in `top` (`%Cpu(s): 12.0 us, 3.0 sy, 0.0 ni, 70.0 id, 14.0 wa, 0.0 hi, 0.5 si, 0.5 st`):

| Field | Means | High when |
|---|---|---|
| `us` | User code | Your application is busy: profile it |
| `sy` | Kernel | Lots of system calls, context switches, or network packets |
| `wa` | Waiting for I/O | The disk is the bottleneck: see [Disk I/O](#disk-io) |
| `st` | Stolen by the hypervisor | On a VM, the host is overcommitted or you've used up burst credits (cloud burstable instances) |
| `id` | Idle | |

High load with idle CPUs means processes stuck waiting, usually on disk or NFS. Find them in the `D` (uninterruptible) state:

```sh
ps -eo state,pid,user,wchan:32,cmd | awk '$1 ~ /^D/'
```

| Part | Means |
|---|---|
| `ps -eo state,pid,user,wchan:32,cmd` | Every process (`-e`), with these columns (`-o`): state letter, PID, user, the kernel function it's waiting in (32 characters wide), and its command |
| `awk '$1 ~ /^D/'` | Keep lines whose first field starts with `D`: uninterruptible sleep, almost always I/O |

## Memory

```sh
free -h
#                total   used   free   shared  buff/cache   available
# Mem:            15Gi  6.1Gi  410Mi    120Mi        9.0Gi       8.9Gi
```

**"free" being low is normal.** Linux uses spare memory as disk cache (`buff/cache`) and gives it back when programs need it. The number that matters is **available**. A server is short of memory when `available` is low and swap use is climbing.

```sh
ps -eo pid,user,rss,%mem,cmd --sort=-rss | head -10            # biggest processes by resident memory (KB)
journalctl -k | grep -iE 'out of memory|oom-kill|killed process'   # did the OOM killer act?
vmstat 1 5                                                      # si/so columns: swapping in/out (bad if constant)
grep -E 'MemAvailable|SwapTotal|SwapFree|Dirty' /proc/meminfo
systemctl status app | grep -i memory                           # a service's memory use (cgroup accounting)
```

When the kernel runs out of memory it kills a process (usually the biggest) and logs it. The fix is never just "restart it": find out why memory grew (a leak, a traffic spike, too many workers, a missing limit), then set a limit so one service can't take down the host: `MemoryMax=2G` in the unit (`systemctl edit app`), or container memory limits.

## Disk full

```sh
df -h                                  # which filesystem is full
df -i                                  # or out of inodes (millions of small files): df -h shows space left, but writes fail
sudo du -xh --max-depth=1 /var 2>/dev/null | sort -rh | head -15   # biggest directories, one level down
```

| Part | Means |
|---|---|
| `du -x` | Stay on this filesystem: don't count `/proc` or other mounts |
| `-h --max-depth=1` | Human-readable sizes, one level of subdirectories |
| `2>/dev/null` | Hide "permission denied" noise |
| `sort -rh` | Sort human sizes (`1G` above `900M`), largest first |
| `head -15` | The top 15 |

Repeat one level deeper into the biggest directory until you find the culprit. The usual ones:

| Culprit | Check | Fix |
|---|---|---|
| Logs | `du -sh /var/log/*` | Fix logrotate (`/etc/logrotate.d/`), lower the log level, ship logs off the host |
| The journal | `journalctl --disk-usage` | `journalctl --vacuum-size=500M`; set `SystemMaxUse=` in `/etc/systemd/journald.conf` |
| Deleted files still open | `sudo lsof -nP +L1` | A process holds a deleted file open, so its space isn't freed. Restart that process (or truncate via `/proc/PID/fd/N`). |
| Container images and volumes | `docker system df` | `docker system prune` (see [Docker cleanup](../../software/containers/docker/07-complex-commands.md#cleanup)) |
| Package cache | `du -sh /var/cache/dnf /var/cache/apt` | `dnf clean all`, `apt clean` |
| Old kernels | `rpm -q kernel` or `dpkg -l 'linux-image-*'` | `dnf remove --oldinstallonly`; `apt autoremove --purge` |
| Core dumps | `coredumpctl list`; `ls /var/lib/systemd/coredump` | Remove old ones; find out why the program crashes |

`du` and `df` disagree when files are deleted but still open: `df` counts the space as used, and `du` can't see the file anymore. `lsof +L1` lists files with a link count below 1, which means deleted.

Never `rm` a log file a service is writing to; truncate it instead: `: > /var/log/app.log` or `truncate -s 0 file`.

### Growing a disk (LVM)

After enlarging the cloud disk or virtual disk:

```sh
lsblk                                  # see the disk, partitions, and LVM volumes
sudo growpart /dev/nvme0n1 3           # grow partition 3 to fill the disk (package cloud-utils-growpart or cloud-guest-utils)
sudo pvresize /dev/nvme0n1p3           # tell LVM the physical volume is bigger
sudo lvextend -r -l +100%FREE /dev/mapper/rhel-root   # grow the logical volume; -r also grows the filesystem
df -h /                                # confirm
```

`lvextend -r` runs `xfs_growfs` (RHEL's default XFS) or `resize2fs` (Ubuntu's default ext4) for you. Without LVM, after `growpart`, run `xfs_growfs /` or `resize2fs /dev/nvme0n1p1` directly.

## Disk I/O

```sh
iostat -xz 1 5                          # per-device: %util, await (ms per request), r/s, w/s (sysstat)
sudo iotop -oPa                         # which processes do the I/O (-o only active, -P processes, -a accumulated)
pidstat -d 1 5                          # per-process read and write rates
```

In `iostat`, look at `await` (average milliseconds per request: low single digits is healthy for SSDs) and `%util` (near 100% on a single disk means saturated; less meaningful for SSDs and RAID, which do many requests in parallel). On cloud volumes, also check the provisioned IOPS and throughput limits: hitting them looks exactly like a slow disk.

## Network

Work up the stack: is the interface up, is there a route, does DNS resolve, does the port answer, does the application answer?

```sh
ip -br addr                             # interfaces and addresses, one per line
ip route                                # routing table; "default via" is the gateway
ip route get 10.20.0.15                 # which route and interface a destination would use
resolvectl query db.internal 2>/dev/null || getent hosts db.internal   # what the system resolver returns
dig +short db.internal                  # what DNS returns (bypasses /etc/hosts)
dig @10.0.0.2 db.internal               # ask one specific DNS server
ping -c 3 10.20.0.15                    # reachable at all? (ICMP is often blocked; failure isn't proof)
mtr -rwc 20 10.20.0.15                  # where along the path packets are lost
nc -zv 10.20.0.15 5432                  # does the TCP port accept connections?
curl -sv https://api.example.com/healthz -o /dev/null   # full HTTP exchange, TLS details, headers
```

Time each phase of an HTTP request:

```sh
curl -so /dev/null -w 'dns %{time_namelookup}s  connect %{time_connect}s  tls %{time_appconnect}s  first-byte %{time_starttransfer}s  total %{time_total}s  status %{http_code}\n' https://example.com/
```

| Field | Ends when | Slow means |
|---|---|---|
| `time_namelookup` | DNS answered | Resolver problems |
| `time_connect` | TCP handshake done | Network latency, or a firewall dropping (not rejecting) packets |
| `time_appconnect` | TLS handshake done | TLS issues, OCSP, slow server CPU |
| `time_starttransfer` | First byte of the response | The application is slow |
| `time_total` | Everything received | Large response or slow transfer |

On the server side:

```sh
ss -tulpn                               # listening sockets and their processes (-p needs root)
ss -tulpn | grep ':5432 '               # is anything listening on the port, and on which address?
ss -s                                   # socket counts by state
ss -tan state time-wait | wc -l         # many TIME-WAIT: lots of short connections
sudo tcpdump -nni any port 5432 -c 20   # do packets arrive at all? (-nn no name lookups, -i any all interfaces)
```

| Symptom | Likely cause |
|---|---|
| "Connection refused" immediately | Reached the host; nothing listens on that port, or it listens only on `127.0.0.1` (check `ss -tulpn`) |
| Hangs, then times out | A firewall drops packets: host firewall, cloud security group or NSG, or a network ACL |
| "No route to host" | Routing, or a firewall rejecting with ICMP |
| Name doesn't resolve | DNS: check `/etc/resolv.conf`, `resolvectl status`, and the record itself with `dig` |
| Works by IP, not by name | DNS, or `/etc/hosts` overriding it |
| Works locally, not remotely | The service is bound to `127.0.0.1`, or the host firewall (`firewall-cmd --list-all`, `ufw status`) |
| TLS errors | Expired or mismatched certificate: `openssl s_client -connect host:443 -servername host < /dev/null 2>/dev/null \| openssl x509 -noout -dates -subject` |

## Services

```sh
systemctl status nginx                  # state, recent log lines, main PID, memory
journalctl -u nginx -b --no-pager | tail -50   # its full log since boot
systemctl cat nginx                     # the unit file and any overrides, as systemd sees them
systemd-analyze verify /etc/systemd/system/app.service   # check a unit file for mistakes
nginx -t; sshd -t; httpd -t; named-checkconf   # most daemons can test their own config: do it before restarting
```

Common causes, in rough order of frequency:

1. **Bad configuration.** The service's own config test (above) says where.
2. **Port in use.** `ss -tulpn | grep :80` shows who has it.
3. **Permissions,** on files, directories, or sockets the service user needs. Check with `sudo -u nginx test -r /path && echo ok`.
4. **SELinux** (RHEL): `ausearch -m AVC -ts recent`. See [SELinux and AppArmor](05-rhel-and-ubuntu.md#selinux-and-apparmor).
5. **A dependency isn't up**: a database, a mount, the network. `systemctl list-dependencies app`.
6. **Restart limit hit.** After repeated crashes, systemd stops trying: "start request repeated too quickly". Fix the cause, then `systemctl reset-failed app`.

Change a packaged unit without editing it: `sudo systemctl edit nginx` creates an override in `/etc/systemd/system/nginx.service.d/override.conf` that survives package updates. Then `systemctl daemon-reload` (the `edit` command does it for you) and restart.

## SSH

From your side, `ssh -vvv user@host` shows exactly where it fails. On the server (through the cloud console, serial console, or another session):

| Message | Check |
|---|---|
| Connection timed out | Network path and firewalls (cloud security group, host firewall). Is the instance up? |
| Connection refused | sshd isn't running (`systemctl status sshd` or `ssh`), or listens on another port |
| Permission denied (publickey) | The key isn't in `~/.ssh/authorized_keys`, or permissions are too open: `~` not writable by others, `~/.ssh` 700, `authorized_keys` 600, owned by the user. On RHEL, also `restorecon -Rv ~/.ssh`. |
| Server log says "Authentication refused: bad ownership or modes" | Exactly that: fix the modes above |
| Disconnects after a few tries | `MaxAuthTries`, or fail2ban banning your IP (`fail2ban-client status sshd`) |
| Host key changed warning | The server was rebuilt, or something is intercepting. Verify the new fingerprint out of band before running `ssh-keygen -R host`. |

```sh
journalctl -u sshd -u ssh -n 50 --no-pager     # the server's view (either family)
sudo sshd -T | grep -Ei 'passwordauth|permitroot|allowusers|allowgroups|port '   # effective settings
```

## Time

Wrong clocks break TLS, Kerberos, token validation, log correlation, and distributed databases.

```sh
timedatectl                       # time zone, and "System clock synchronized: yes"
chronyc tracking                  # offset from the reference, and its stratum
chronyc sources -v                # which servers, and which one is selected (*)
```

Servers should run in UTC (`timedatectl set-timezone UTC`), so logs line up across regions. In the cloud, use the provider's time service (AWS: 169.254.169.123; Azure VMs get time from the host), which `chrony` on cloud images usually already does.

## Processes and signals

```sh
pgrep -a nginx                         # PIDs and command lines matching a name
pstree -p | less                       # the process tree, with PIDs
kill -TERM 1234                        # ask politely (the default): the process can clean up
kill -KILL 1234                        # force (-9): no cleanup; last resort
pkill -HUP -x rsyslogd                 # signal by exact name; HUP often means "reload config"
renice +10 -p 1234                     # lower a running process's priority
lsof -p 1234                           # files, sockets, and libraries a process has open
sudo strace -fp 1234 -e trace=network,file -s 200   # what system calls it's making right now (package strace)
cat /proc/1234/status; ls -l /proc/1234/cwd; tr '\0' ' ' < /proc/1234/cmdline   # straight from the kernel
```

Prefer `systemctl` for services (`restart`, `reload`, `kill --signal=HUP`), so systemd's view of the service stays correct.

## Keeping history: sar

`sysstat` records CPU, memory, disk, and network every 10 minutes when its timer or cron job is on, so you can see what happened at 3 a.m. after the fact:

```sh
sudo systemctl enable --now sysstat     # both families; on Ubuntu also set ENABLED="true" in /etc/default/sysstat
sar -u                                  # CPU today
sar -r -f /var/log/sa/sa13              # memory on the 13th (RHEL path; Ubuntu: /var/log/sysstat/sa13)
sar -n DEV 1 5                          # network interfaces, live
```

## Before you reboot

A reboot hides the evidence. Before rebooting a misbehaving server, capture what you can: run [system-report.sh](scripts/system-report.sh) and save the output, copy recent logs (`journalctl -b > /tmp/boot.log`), and note the time. On RHEL, `sos report` collects a complete diagnostic archive for support cases (also available on Ubuntu as the `sosreport` package).
