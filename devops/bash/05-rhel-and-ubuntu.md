# RHEL and Ubuntu

[← Bash 101](README.md)

The same job on the two server families you'll meet most: **Red Hat Enterprise Linux** (RHEL), with its compatible rebuilds Rocky Linux and AlmaLinux and its upstream CentOS Stream, and **Ubuntu** (from the Debian family). The shell, systemd, SSH, and most tools are the same; packages, file locations, security layers, and a few service names are not. Each section is a side-by-side table, with the gotchas below it.

> Find out which you're on: `cat /etc/os-release`. Scripts should read `ID` and `ID_LIKE` from that file, as `detect_os` in [lib/common.sh](scripts/lib/common.sh) does, rather than test for `/etc/redhat-release`.

| Section | Covers |
|---|---|
| [Release and support model](#release-and-support-model) | Versions, lifecycles, subscriptions |
| [Packages](#packages) | dnf and rpm, apt and dpkg |
| [Repositories](#repositories) | Subscriptions, AppStream, EPEL, CRB; universe, PPAs, Pro |
| [Services and names](#services-and-names) | Units that differ by name, and config layouts |
| [Firewall](#firewall) | firewalld and ufw |
| [SELinux and AppArmor](#selinux-and-apparmor) | The mandatory access control layer, and how to troubleshoot denials |
| [Users and sudo](#users-and-sudo) | wheel and sudo |
| [Networking](#networking) | NetworkManager and netplan |
| [Logs](#logs) | journald and the classic files |
| [Updates and reboots](#updates-and-reboots) | Automatic updates, reboot checks, live patching |
| [Boot, kernel, and storage](#boot-kernel-and-storage) | GRUB, initramfs, LVM, filesystems |
| [Gotchas](#gotchas) | Things that bite people moving between the two |

---

## Release and support model

| | RHEL (and Rocky, AlmaLinux) | Ubuntu |
|---|---|---|
| Major releases | About every 3 years (RHEL 8 in 2019, 9 in 2022, 10 in 2025) | An LTS every 2 years in April (22.04, 24.04, 26.04), interim releases every 6 months |
| Support | 10 years per major release, with paid extensions beyond | 5 years standard for LTS, plus 5 more with Ubuntu Pro (free for personal use on a few machines) |
| Minor updates | Minor releases (9.4, 9.5...) about every 6 months; you move with them unless on an extended-support stream | Point releases (24.04.1, .2...) roll up updates; nothing to choose |
| Access | A Red Hat subscription (free Developer subscription for individuals). Rocky Linux and AlmaLinux are free rebuilds. | Free. Ubuntu Pro adds extended security maintenance, livepatch, and compliance tooling. |
| Use on servers | Use LTS releases only | Use LTS releases only; interim releases expire in 9 months |

For containers, Red Hat publishes the **Universal Base Image** (UBI), freely redistributable without a subscription: `registry.access.redhat.com/ubi9/ubi`, plus `ubi-minimal` and `ubi-micro`. UBI repositories have a subset of RHEL's packages.

## Packages

| Task | RHEL | Ubuntu |
|---|---|---|
| Refresh metadata | `dnf makecache` (dnf also refreshes automatically) | `apt update` (required before installs) |
| Search | `dnf search nginx` | `apt search nginx` |
| Details | `dnf info nginx` | `apt show nginx` |
| Install | `dnf install nginx` | `apt install nginx` |
| Install a local file | `dnf install ./app.rpm` | `apt install ./app.deb` |
| Remove | `dnf remove nginx` | `apt remove nginx` (`apt purge` also deletes its config) |
| Remove unneeded dependencies | `dnf autoremove` | `apt autoremove` |
| Upgrade everything | `dnf upgrade` | `apt upgrade` (or `apt full-upgrade`, which may remove packages to resolve changes) |
| Security updates only | `dnf upgrade --security` | `unattended-upgrade` runs them; `apt list --upgradable` shows all |
| Updates for a CVE | `dnf updateinfo list --cve CVE-2024-6387` | `pro fix CVE-2024-6387` |
| Which package owns a file | `rpm -qf /usr/sbin/sshd` | `dpkg -S /usr/sbin/sshd` |
| Which package would provide a file | `dnf provides '*/bin/dig'` | `apt-file search bin/dig` (install `apt-file`, then `apt-file update`) |
| List a package's files | `rpm -ql openssh-server` | `dpkg -L openssh-server` |
| Installed packages | `rpm -qa \| sort` or `dnf list --installed` | `dpkg -l` or `apt list --installed` |
| Hold at a version | `dnf versionlock add kernel` (package `python3-dnf-plugin-versionlock`) | `apt-mark hold linux-image-generic` |
| History and undo | `dnf history`, `dnf history info 12`, `dnf history undo 12` | `/var/log/apt/history.log` (no built-in undo) |
| Verify installed files | `rpm -Va` (changed files, permissions, owners) | `debsums -c` (package `debsums`) |
| Changelog | `rpm -q --changelog openssh-server \| head` | `apt changelog openssh-server` |
| Clean the cache | `dnf clean all` | `apt clean` |
| Low-level tool, format | `rpm`, `.rpm` | `dpkg`, `.deb` |

In scripts, use non-interactive forms: `dnf install -y`, and `DEBIAN_FRONTEND=noninteractive apt-get install -y` (`apt-get` rather than `apt`, whose output isn't stable for scripts).

## Repositories

| | RHEL | Ubuntu |
|---|---|---|
| Repository config | `/etc/yum.repos.d/*.repo` | `/etc/apt/sources.list.d/` (`ubuntu.sources` in deb822 format since 24.04) |
| List | `dnf repolist` (`dnf repolist all` includes disabled) | `apt-cache policy` |
| Enable access | `subscription-manager register`, then repositories come with the subscription | Nothing to register |
| Standard repositories | **BaseOS** (core OS) and **AppStream** (applications, languages, databases, often in several versions) | **main** (supported), **universe** (community), **restricted**, **multiverse** |
| Extra developer packages | **CRB** (CodeReady Linux Builder): `subscription-manager repos --enable codeready-builder-for-rhel-9-$(arch)-rpms`; on Rocky and Alma: `dnf config-manager --set-enabled crb` | In universe |
| Community extras | **EPEL**, from Fedora: `dnf install https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm` on RHEL, `dnf install epel-release` on Rocky and Alma. Needs CRB. | universe, and **PPAs**: `add-apt-repository ppa:owner/name` |
| Third-party vendor | A `.repo` file with a `gpgkey=` URL | A `.sources` (or `.list`) file with `Signed-By:` pointing at a key in `/etc/apt/keyrings/` |
| Multiple versions of a stack | AppStream streams (RHEL 9 and later offer extra versions as separately named packages, such as `python3.12` or `nodejs:20` modules on RHEL 8 and 9) | Versioned package names (`postgresql-16`), or the vendor's repository |

Every third-party repository is a supply-chain dependency: it can ship anything to your servers as root. Prefer the distribution's packages, pin vendor repositories to signed keys (never `apt-key add`, which trusts a key for every repository, or `gpgcheck=0`), and record why each one is there.

## Services and names

systemd is the same on both: `systemctl status|start|stop|restart|reload|enable|disable NAME`, `journalctl -u NAME`. Only some names and config layouts differ:

| Software | RHEL unit | Ubuntu unit | Config |
|---|---|---|---|
| SSH server | `sshd` | `ssh` (socket-activated by `ssh.socket` on 22.10 and later) | `/etc/ssh/sshd_config.d/*.conf` on both |
| Apache | `httpd` | `apache2` | `/etc/httpd/conf.d/*.conf` vs `/etc/apache2/sites-available/` plus `a2ensite`, `a2enmod` |
| nginx | `nginx` | `nginx` | `/etc/nginx/conf.d/` on both; Ubuntu also `sites-available` and `sites-enabled` |
| Cron | `crond` (package `cronie`) | `cron` | `/etc/cron.d/`, `crontab -e` on both |
| Time sync | `chronyd` | `chrony` (if installed; otherwise `systemd-timesyncd`) | `/etc/chrony.conf` vs `/etc/chrony/chrony.conf` |
| Firewall | `firewalld` | `ufw` | See below |
| DNS server | `named` (package `bind`) | `named` (package `bind9`) | `/etc/named.conf` vs `/etc/bind/` |
| Syslog | `rsyslog` | `rsyslog` | `/etc/rsyslog.d/` on both |
| Network | `NetworkManager` | `systemd-networkd` (servers, through netplan) | See below |

Defaults also differ: **Ubuntu starts most services when their package is installed; RHEL doesn't.** On RHEL, `dnf install nginx` is followed by `systemctl enable --now nginx`.

## Firewall

| Task | RHEL: firewalld | Ubuntu: ufw |
|---|---|---|
| State | `firewall-cmd --state`; `firewall-cmd --list-all` | `ufw status verbose` |
| On by default | Yes, with the `public` zone allowing SSH and a few others | Installed but **inactive** |
| Allow a service | `firewall-cmd --permanent --add-service=https` | `ufw allow https` |
| Allow a port | `firewall-cmd --permanent --add-port=8080/tcp` | `ufw allow 8080/tcp` |
| Allow from one network | `firewall-cmd --permanent --add-rich-rule='rule family=ipv4 source address=10.0.0.0/8 port port=5432 protocol=tcp accept'` | `ufw allow from 10.0.0.0/8 to any port 5432 proto tcp` |
| Remove | `firewall-cmd --permanent --remove-port=8080/tcp` | `ufw delete allow 8080/tcp` |
| Apply saved rules | `firewall-cmd --reload` | Rules apply immediately |
| Enable | `systemctl enable --now firewalld` | `ufw enable` (allow SSH first!) |

firewalld's `--permanent` writes the saved configuration but doesn't change the running rules until `--reload`; without `--permanent`, a change applies now and is lost at the next reload. Both tools drive **nftables** underneath. [configure-firewall.sh](scripts/configure-firewall.sh) handles both.

In the cloud, security groups (AWS) and network security groups (Azure) filter traffic before it reaches the host. Use both layers: the cloud's for the network, the host's for defense in depth.

## SELinux and AppArmor

Both add **mandatory access control**: rules that confine services even when they run as root, so a compromised web server can't read `/etc/shadow` or SSH keys. RHEL uses **SELinux**, enforcing by default. Ubuntu uses **AppArmor**, with profiles for selected services.

| Task | SELinux (RHEL) | AppArmor (Ubuntu) |
|---|---|---|
| Status | `getenforce`; `sestatus` | `aa-status` |
| How it decides | Every file, process, and port has a **label** (context); policy says which process labels can touch which file labels | Per-program **profiles** list the paths and capabilities a program may use |
| See labels or profiles | `ls -Z /var/www`; `ps -eZ \| grep httpd` | Profiles in `/etc/apparmor.d/` |
| Find denials | `ausearch -m AVC,USER_AVC -ts recent`; `journalctl -t setroubleshoot` | `journalctl -k \| grep 'apparmor="DENIED"'` |
| Explain a denial | `ausearch -m AVC -ts recent \| audit2why`; `sealert -a /var/log/audit/audit.log` (package `setroubleshoot-server`) | Read the profile named in the message |
| Fix a file label | `restorecon -Rv /path` (back to the policy's default) | (not label-based) |
| Allow a new path | `semanage fcontext -a -t httpd_sys_content_t '/srv/www(/.*)?'` then `restorecon -Rv /srv/www` | Edit the profile or add to `/etc/apparmor.d/local/`, then `apparmor_parser -r` the profile |
| Allow a new port | `semanage port -a -t http_port_t -p tcp 8081` | (not port-based) |
| Common feature switches | `getsebool -a \| grep httpd`; `setsebool -P httpd_can_network_connect on` (`-P`: persist) | |
| Stop enforcing one program | `semanage permissive -a httpd_t` (temporary troubleshooting) | `aa-complain /usr/sbin/nginx` (package `apparmor-utils`) |

**The classic SELinux incident:** content copied or moved into a web root keeps its old label, and the service gets "permission denied" with perfectly good Unix permissions. `ls -Z` shows the wrong label; `restorecon -Rv` fixes it. `cp` creates files with the destination's label; `mv` keeps the source's.

**Don't disable SELinux.** `setenforce 0` (until reboot) or `SELINUX=disabled` removes a layer that contains real attacks. Find the denial, then fix the label, boolean, or port. If you must test, make one domain permissive, never the whole system.

## Users and sudo

| | RHEL | Ubuntu |
|---|---|---|
| Admin group | `wheel` | `sudo` (and `admin` on very old releases) |
| Create a user | `useradd -m -s /bin/bash -G wheel alice` | Same, or `adduser alice` (interactive, friendly) and `usermod -aG sudo alice` |
| Regular UIDs start at | 1000 | 1000 |
| Default shell in `useradd` | `/bin/bash` | `/bin/sh` unless `-s /bin/bash` (set in `/etc/default/useradd`) |
| sudo drop-ins | `/etc/sudoers.d/` (edit with `visudo -f`) | Same |
| Lockout after failed logins | `pam_faillock`, configured by default (`faillock --user alice` to see, `--reset` to clear) | `pam_faillock` is available but not enabled by default |

[create-admin-user.sh](scripts/create-admin-user.sh) picks the right group automatically. Files in `/etc/sudoers.d/` whose names contain a `.` or end in `~` are **ignored** by sudo, so `90-alice.conf` silently does nothing; name it `90-alice`.

## Networking

| Task | RHEL: NetworkManager | Ubuntu Server: netplan |
|---|---|---|
| Show addresses and routes | `ip -br addr`, `ip route` (both) | Same |
| Show connections | `nmcli con show`; `nmcli dev status` | `netplan status` (24.04 and later); `networkctl status` |
| Static address | `nmcli con mod eth0 ipv4.method manual ipv4.addresses 10.0.0.5/24 ipv4.gateway 10.0.0.1 ipv4.dns 10.0.0.2` then `nmcli con up eth0` | YAML in `/etc/netplan/*.yaml` (example below), then `netplan try` |
| Config files | `/etc/NetworkManager/system-connections/*.nmconnection` (RHEL 9 and later; older `ifcfg` files are deprecated) | `/etc/netplan/*.yaml`, rendered to systemd-networkd |
| DNS in use | `cat /etc/resolv.conf`; `nmcli dev show \| grep DNS` | `resolvectl status` (systemd-resolved; `/etc/resolv.conf` points at 127.0.0.53) |
| Hostname | `hostnamectl set-hostname web-01` (both) | Same, but cloud-init may reset it at boot: set `preserve_hostname: true` |

```yaml
# /etc/netplan/60-static.yaml (mode 600)
network:
  version: 2
  ethernets:
    eth0:
      addresses: [10.0.0.5/24]
      routes:
        - to: default
          via: 10.0.0.1
      nameservers:
        addresses: [10.0.0.2]
```

**Use `netplan try`, not `netplan apply`, on a remote machine.** It applies the change and rolls it back after 120 seconds unless you confirm, so a typo doesn't strand the server. On RHEL, `nmcli` changes are similarly risky over SSH: schedule a revert first (`sleep 120 && nmcli con up eth0-old &`), or use the console.

On cloud VMs, both use **cloud-init** at first boot, and the cloud's DHCP normally configures networking. Change it only when you need to.

## Logs

| | RHEL | Ubuntu |
|---|---|---|
| Everything, structured | `journalctl` (both) | Same |
| General system log | `/var/log/messages` | `/var/log/syslog` |
| Authentication (SSH, sudo) | `/var/log/secure` | `/var/log/auth.log` |
| Kernel | `journalctl -k` | `journalctl -k`, `/var/log/kern.log` |
| Package history | `/var/log/dnf.log`, `dnf history` | `/var/log/apt/history.log`, `/var/log/dpkg.log` |
| SELinux and audit | `/var/log/audit/audit.log` (`ausearch`) | `/var/log/audit/audit.log` if `auditd` is installed |
| Rotation | `logrotate` (`/etc/logrotate.d/`) on both | Same |

```sh
journalctl -u nginx --since "1 hour ago"       # one service
journalctl -p warning -b                       # warnings and worse since this boot
journalctl -b -1 -e                            # the previous boot, jump to the end (after a crash)
journalctl -f -u sshd -u ssh                   # follow SSH on either family
journalctl --disk-usage; sudo journalctl --vacuum-time=14d   # size, and trim
```

The journal survives reboots only if `/var/log/journal` exists (or `Storage=persistent` in `/etc/systemd/journald.conf`). Check with `ls /var/log/journal`; `journalctl --list-boots` showing only one boot means it isn't persistent.

## Updates and reboots

| | RHEL | Ubuntu |
|---|---|---|
| Automatic security updates | `dnf-automatic` (`/etc/dnf/automatic.conf`, `dnf-automatic.timer`) | `unattended-upgrades` (installed and on by default on Ubuntu Server) |
| Does a reboot need to happen? | `needs-restarting -r` (exit 1 means yes; package `dnf-utils`) | `test -f /var/run/reboot-required` |
| Which services need restarting | `needs-restarting -s` | `needrestart` (runs automatically after apt on Ubuntu Server) |
| Kernel patches without reboot | `kpatch` (with a subscription) | Canonical Livepatch: `pro enable livepatch` |
| Script | [enable-auto-updates.sh](scripts/enable-auto-updates.sh) | Same script |

Automatic updates install packages, but a new kernel, glibc, or OpenSSL only takes effect after a restart. Schedule reboots (rolling, one host at a time behind a load balancer), or the patched packages sit unused.

## Boot, kernel, and storage

| Task | RHEL | Ubuntu |
|---|---|---|
| Add a kernel argument | `grubby --update-kernel=ALL --args="console=ttyS0"` | Edit `GRUB_CMDLINE_LINUX` in `/etc/default/grub`, then `update-grub` |
| Default kernel | `grubby --default-kernel` | First entry in GRUB; `uname -r` for the running one |
| Rebuild the initramfs | `dracut -f` | `update-initramfs -u` |
| Default root filesystem | XFS on LVM | ext4 (LVM optional in the installer) |
| Grow a filesystem | `xfs_growfs /` (XFS can't shrink) | `resize2fs /dev/mapper/vg-root` (ext4; can shrink offline) |
| Kernel parameters | `/etc/sysctl.d/*.conf`, then `sysctl --system` (both) | Same |

The LVM workflow to grow a disk is the same on both, and is in [Administration](06-administration.md#disk-full).

## Gotchas

| Symptom | Family | Cause and fix |
|---|---|---|
| `dnf install curl` fails with "conflicts with curl-minimal" | RHEL 9 | Minimal installs and containers ship `curl-minimal`. It provides the `curl` command; don't install `curl` on top, or use `dnf swap curl-minimal curl`. [bootstrap-server.sh](scripts/bootstrap-server.sh) handles this. |
| `pip install` fails with "externally-managed-environment" | Ubuntu 23.04 and later | The system Python is managed by apt (PEP 668). Use a virtual environment (`python3 -m venv`), `pipx` for tools, or the distribution package (`apt install python3-requests`). |
| `/bin/sh` scripts fail with "Syntax error: ( unexpected" | Ubuntu | `/bin/sh` is dash, not Bash. Use `#!/usr/bin/env bash` for Bash scripts. |
| Service runs fine as root by hand, fails under systemd with permission denied | RHEL | SELinux: the binary or its files are mislabeled (often after copying from elsewhere). `ausearch -m AVC -ts recent`, then `restorecon`. |
| Web server can't connect to a backend: "Permission denied" | RHEL | SELinux boolean: `setsebool -P httpd_can_network_connect on`. |
| Service won't bind to a non-standard port | RHEL | SELinux port label: `semanage port -a -t http_port_t -p tcp 8081`. |
| Package installed, but the service isn't running | RHEL | RHEL doesn't auto-start services: `systemctl enable --now`. |
| `apt install` prompts and hangs in automation | Ubuntu | Set `DEBIAN_FRONTEND=noninteractive`, and pass `-y`. Some packages also ask about config files: `-o Dpkg::Options::=--force-confold`. |
| Hostname changes back after reboot | Ubuntu on cloud | cloud-init manages it: `preserve_hostname: true` in `/etc/cloud/cloud.cfg`. |
| SSH config change has no effect | Both | sshd uses the **first** value it reads, and `sshd_config.d/*.conf` files are read at the top, in name order. A `50-cloud-init.conf` setting beats your later line. Use a low-numbered drop-in and check with `sshd -T`. |
| `systemctl restart ssh` says the unit isn't found | RHEL | It's `sshd` on RHEL (and `ssh` on Ubuntu). |
| No `docker` package | RHEL | RHEL ships Podman. Install Docker from Docker's repository ([install-docker.sh](scripts/install-docker.sh)), or use Podman with `podman-docker`. See [Docker 101](../docker/README.md). |
| A `.repo` or `.sources` file you added breaks every update | Both | A vendor repository is down or its key expired. `dnf --disablerepo=NAME` or comment out the source, then fix or remove it. |
