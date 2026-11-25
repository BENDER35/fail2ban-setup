# Didactic guide — install and configure fail2ban

This guide explains **what** the script does at each step, not only which command to run. It works on most Linux distributions thanks to automatic package-manager detection.

## 1. What fail2ban does

fail2ban reads log files (or the systemd journal), looks for failed authentication attempts, and creates a temporary firewall rule to block the offending IP address. A block is called a **ban**; the rule that defines when to ban is called a **jail**.

Key ideas:

- **filter**: a regular expression that recognizes a failed login.
- **jail**: a filter plus `logpath`, `port`, `findtime`, `maxretry` and `bantime`.
- **action**: what happens when the threshold is reached (`iptables`, `nftables`, `ufw`, etc.).

## 2. Before you start

You need:

- root access (or `sudo`);
- a working SSH connection that you do **not** want to lose;
- your own public IP noted down, so you can add it to `ignoreip`.

Check the current status:

```bash
sshd -t                       # validate the SSH configuration
ip addr show                  # see your addresses
sudo fail2ban-client status   # only if fail2ban is already installed
```

## 3. Run the script

```bash
git clone https://github.com/BENDER35/fail2ban-setup.git
cd fail2ban-setup
chmod +x install_fail2ban.sh
sudo ./install_fail2ban.sh
```

If you want to see everything without changing the system:

```bash
./install_fail2ban.sh --dry-run
```

## 4. Answering each question

The script asks, in order:

1. **`ignoreip`** — put `127.0.0.1/8 ::1` plus your own IP, e.g. `127.0.0.1/8 ::1 203.0.113.10`.
2. **`bantime`** — how long the IP stays blocked. `1h` is a reasonable start; `1d` is stricter.
3. **`findtime`** — the time window counted by fail2ban. With `10m` and `maxretry=5`, five failures in ten minutes trigger a ban.
4. **`maxretry`** — number of allowed failures. `5` avoids blocking honest users who mistype a password.
5. **`banaction`** — the script detects `nftables`, `ufw`, `firewalld` or `iptables`. If your firewall is inactive, `iptables` is used as a safe default.
6. **`backend`** — `systemd` reads the journal; `polling` reads files such as `/var/log/auth.log` or `/var/log/secure`.
7. **`logpath`** — `journal` with the systemd backend, otherwise the detected log file.
8. **`port`** — use your real SSH port. If you changed SSH to `2222`, enter `2222`; otherwise fail2ban would watch the wrong port.
9. **`[sshd]` jail** — normally answer `s` (yes). You may set a stricter `maxretry` only for SSH.
10. **`destemail`** — leave empty if you do not have a working mail server. If you fill it, the script selects `action_mwl`, which needs `sendmail` or `mail`.
11. **`loglevel`** — `INFO` is enough; use `DEBUG` only while troubleshooting.
12. **Extra jails** — enable `apache-auth`, `nginx-http-auth`, `postfix` or `dovecot` only for services that really run on the host.
13. **Start the service** — answer `s` to enable it at boot and start it immediately.

## 5. What the script writes

It creates `/etc/fail2ban/jail.local`. Example:

```ini
[DEFAULT]
ignoreip  = 127.0.0.1/8 ::1 203.0.113.10
bantime   = 1h
findtime  = 10m
maxretry  = 5
backend   = systemd
banaction = nftables
action    = %(action_)s
loglevel  = INFO

[sshd]
enabled  = true
port     = 22
logpath  = journal
```

`jail.conf` is never edited: upgrades to the package will not overwrite your choices. If a `jail.local` already exists, a timestamped copy is saved in `/etc/fail2ban/backups/`.

## 6. Verify that it works

```bash
sudo systemctl status fail2ban
sudo fail2ban-client status
sudo fail2ban-client status sshd
sudo tail -f /var/log/fail2ban.log
```

To test safely from a **second** machine (never from your only SSH session):

```bash
ssh wronguser@YOUR_SERVER   # repeat 6 times
sudo fail2ban-client status sshd
```

You should see `Banned IP List` containing the test machine address. Unban it with:

```bash
sudo fail2ban-client set sshd unbanip TEST_IP
```

## 7. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `No file(s) found` | wrong `logpath` | Check `journalctl -u ssh` or `/var/log/auth.log`, then re-run the script |
| `ERROR  No failures found for the given jail` | service not started | `sudo systemctl restart fail2ban` |
| Your own IP is banned | IP missing from `ignoreip` | Add it and run `sudo fail2ban-client reload` |
| `banaction` fails | firewall backend mismatch | Change `banaction` to the firewall you actually use |
| Nothing is banned | wrong `port` or `maxretry` too high | Confirm the SSH port and lower `maxretry` |

## 8. Distribution notes

| Family | Install command used by the script |
|---|---|
| Debian/Ubuntu | `apt-get update && apt-get install -y fail2ban` |
| RHEL/Rocky/Alma | `dnf install -y epel-release` then `dnf install -y fail2ban` |
| Fedora | `dnf install -y fail2ban` |
| openSUSE | `zypper --non-interactive install -y fail2ban` |
| Alpine | `apk add --no-cache fail2ban` |
| Arch/Manjaro | `pacman -Sy --noconfirm fail2ban` |
| Void | `xbps-install -Sy fail2ban` |
| Gentoo | `emerge --noreplace net-analyzer/fail2ban` |
| Solus | `eopkg install -y fail2ban` |
| NixOS | set `services.fail2ban.enable = true;` in `configuration.nix` |
| Slackware | build with `sbopkg -i fail2ban` |

## 9. Mirrors and releases

The repository is mirrored in both directions: a push to GitHub is copied to GitLab by GitHub Actions, and a push to GitLab is copied to GitHub by GitLab CI. Both jobs refuse to force-push. See [MIRROR_VERIFICATION.md](MIRROR_VERIFICATION.md).

Create a release ZIP with:

```bash
make release
```
