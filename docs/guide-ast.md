# Guía didáctica — instalar y configurar fail2ban (asturianu/bable)

Esta guía esplica **qué fai** el script en cada pasu, non sólo qué comandu copies. Funciona na mayoría de les distribuciones Linux porque detecta automáticamente'l xestor de paquetes.

## 1. Qué fai fail2ban

fail2ban llee los ficheros de log (o'l journal de systemd), busca intentos fallíos d'autenticación y crea una regla temporal de firewall pa bloquiar la IP responsable. Al bloqueu dícese-y **baneu**; a la regla que decide cuándo banear dícese-y **jaula** (*jail*).

Idees principales:

- **filtru**: espresión regular que reconoz un login fallíu;
- **jaula**: filtru más `logpath`, `port`, `findtime`, `maxretry` y `bantime`;
- **aición**: lo que asocede al superase'l llende (`iptables`, `nftables`, `ufw`, etc.).

## 2. Antes d'empezar

Precises:

- permisos de root (o `sudo`);
- una conexón SSH que **non** quieras perder;
- anotar la to IP pública pa ponela en `ignoreip`.

Comprobaciones previes:

```bash
sshd -t                       # valida la configuración d'SSH
ip addr show                  # amuesa les tos direiciones
sudo fail2ban-client status   # sólo si fail2ban ya tá instaláu
```

## 3. Executar el script

```bash
git clone https://github.com/BENDER35/fail2ban-setup.git
cd fail2ban-setup
chmod +x install_fail2ban.sh
sudo ./install_fail2ban.sh
```

Si quies velo too sin camudar el sistema:

```bash
./install_fail2ban.sh --dry-run
```

## 4. Cómo responder a cada pregunta

El script pregunta, nesti orde:

1. **`ignoreip`** — escribe `127.0.0.1/8 ::1` y la to propia IP, por exemplu `127.0.0.1/8 ::1 203.0.113.10`.
2. **`bantime`** — cuánto dura'l baneu. `1h` ye un bon entamu; `1d` ye más estrictu.
3. **`findtime`** — la ventana de tiempu que fail2ban cuenta. Con `10m` y `maxretry=5`, cinco fallos en diez minutos provoquen el baneu.
4. **`maxretry`** — fallos permiteos. `5` evita bloquiar a usuarios que escriben mal la contraseña.
5. **`banaction`** — el script detecta `nftables`, `ufw`, `firewalld` o `iptables`. Si'l to firewall tá inactivu, usa `iptables` por seguridá.
6. **`backend`** — `systemd` llee'l journal; `polling` llee ficheros como `/var/log/auth.log` o `/var/log/secure`.
7. **`logpath`** — `journal` con backend systemd; si non, el fichero de log detectáu.
8. **`port`** — pon el to puertu SSH real. Si camudasti SSH al `2222`, escribe `2222`; si non, fail2ban vigilará'l puertu equivocáu.
9. **Jaula `[sshd]`** — normalmente responde `s`. Pues poner un `maxretry` más estrictu sólo pa SSH.
10. **`destemail`** — déxalu vacíu si nun tienes corréu funcionando. Si lu rellenes, el script usa `action_mwl`, que preciesa `sendmail` o `mail`.
11. **`loglevel`** — `INFO` basta; usa `DEBUG` sólo pa diagnosticar.
12. **Jaules extra** — activa `apache-auth`, `nginx-http-auth`, `postfix` o `dovecot` sólo si esos servicios tan na máquina.
13. **Arrancar el serviciu** — responde `s` pa habilitalu nel arranque y llevantalu yá.

## 5. Qué escribe el script

Crea `/etc/fail2ban/jail.local`. Exemplu:

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

Nunca edita `jail.conf`: asina les actualizaciones del paquete non sobrescriben les tos decisiones. Si yá esistía un `jail.local`, guarda una copia con data en `/etc/fail2ban/backups/`.

## 6. Verificar que funciona

```bash
sudo systemctl status fail2ban
sudo fail2ban-client status
sudo fail2ban-client status sshd
sudo tail -f /var/log/fail2ban.log
```

Pa probar de forma segura dende una **segunda** máquina (nunca dende la to única sesión SSH):

```bash
ssh usuariu_incorrectu@TO_SERVIDOR   # repite 6 vegaes
sudo fail2ban-client status sshd
```

Debies ver la IP de prueba en `Banned IP List`. Pa desbaniala:

```bash
sudo fail2ban-client set sshd unbanip IP_DE_PRUEBA
```

## 7. Solución de problemes

| Síntoma | Causa | Solución |
|---|---|---|
| `No file(s) found` | `logpath` equivocáu | Revisa `journalctl -u ssh` o `/var/log/auth.log` y vuelve executar el script |
| `No failures found for the given jail` | serviciu paráu | `sudo systemctl restart fail2ban` |
| La to IP foi baneada | IP ausente en `ignoreip` | Añádela y executa `sudo fail2ban-client reload` |
| Falla `banaction` | backend de firewall distintu | Camuda `banaction` al firewall que uses de verdá |
| Nun banea nada | puertu erróneu o `maxretry` altu | Confirma'l puertu SSH y baxa `maxretry` |

## 8. Notes por distribución

| Familia | Comandu que usa el script |
|---|---|
| Debian/Ubuntu | `apt-get update && apt-get install -y fail2ban` |
| RHEL/Rocky/Alma | `dnf install -y epel-release` y depués `dnf install -y fail2ban` |
| Fedora | `dnf install -y fail2ban` |
| openSUSE | `zypper --non-interactive install -y fail2ban` |
| Alpine | `apk add --no-cache fail2ban` |
| Arch/Manjaro | `pacman -Sy --noconfirm fail2ban` |
| Void | `xbps-install -Sy fail2ban` |
| Gentoo | `emerge --noreplace net-analyzer/fail2ban` |
| Solus | `eopkg install -y fail2ban` |
| NixOS | `services.fail2ban.enable = true;` en `configuration.nix` |
| Slackware | compilar con `sbopkg -i fail2ban` |

## 9. Espeyos y releases

El repositorio sincronízase en dambos sentíos: un push a GitHub cópialu a GitLab con GitHub Actions, y un push a GitLab cópialu a GitHub con GitLab CI. Dambos refugan forzar l'historial. Mira [MIRROR_VERIFICATION.md](MIRROR_VERIFICATION.md).

Pa crear el ZIP de release:

```bash
make release
```
