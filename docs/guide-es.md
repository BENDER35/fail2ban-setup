# Guía didáctica — instalar y configurar fail2ban

Esta guía explica **qué hace** el script en cada paso, no sólo qué comando hay que copiar. Funciona en la mayoría de distribuciones Linux porque detecta automáticamente el gestor de paquetes.

## 1. Qué hace fail2ban

fail2ban lee archivos de log (o el journal de systemd), busca intentos fallidos de autenticación y crea una regla temporal de firewall para bloquear la IP responsable. Al bloqueo se le llama **baneo**; a la regla que decide cuándo banear se le llama **jaula** (*jail*).

Conceptos clave:

- **filtro**: expresión regular que reconoce un login fallido;
- **jaula**: filtro más `logpath`, `port`, `findtime`, `maxretry` y `bantime`;
- **acción**: lo que ocurre al superarse el umbral (`iptables`, `nftables`, `ufw`, etc.).

## 2. Antes de empezar

Necesitas:

- permisos de root (o `sudo`);
- una conexión SSH que **no** quieras perder;
- tu IP pública anotada para añadirla a `ignoreip`.

Comprobaciones previas:

```bash
sshd -t                       # valida la configuración de SSH
ip addr show                  # muestra tus direcciones
sudo fail2ban-client status   # sólo si fail2ban ya está instalado
```

## 3. Ejecutar el script

```bash
git clone https://github.com/BENDER35/fail2ban-setup.git
cd fail2ban-setup
chmod +x install_fail2ban.sh
sudo ./install_fail2ban.sh
```

Para ver todo sin modificar el sistema:

```bash
./install_fail2ban.sh --dry-run
```

## 4. Cómo responder a cada pregunta

El script pregunta, en este orden:

1. **`ignoreip`** — escribe `127.0.0.1/8 ::1` y tu propia IP, por ejemplo `127.0.0.1/8 ::1 203.0.113.10`.
2. **`bantime`** — cuánto dura el baneo. `1h` es un buen inicio; `1d` es más estricto.
3. **`findtime`** — ventana de tiempo que fail2ban cuenta. Con `10m` y `maxretry=5`, cinco fallos en diez minutos provocan el baneo.
4. **`maxretry`** — fallos permitidos. `5` evita bloquear a usuarios que escriben mal la contraseña.
5. **`banaction`** — el script detecta `nftables`, `ufw`, `firewalld` o `iptables`. Si tu firewall está inactivo, usa `iptables` por seguridad.
6. **`backend`** — `systemd` lee el journal; `polling` lee archivos como `/var/log/auth.log` o `/var/log/secure`.
7. **`logpath`** — `journal` con backend systemd; si no, el archivo de log detectado.
8. **`port`** — pon tu puerto SSH real. Si cambiaste SSH al `2222`, escribe `2222`; si no, fail2ban vigilará el puerto equivocado.
9. **Jaula `[sshd]`** — normalmente responde `s`. Puedes poner un `maxretry` más estricto sólo para SSH.
10. **`destemail`** — déjalo vacío si no tienes correo funcionando. Si lo rellenas, el script usa `action_mwl`, que necesita `sendmail` o `mail`.
11. **`loglevel`** — `INFO` basta; usa `DEBUG` sólo para diagnosticar.
12. **Jaulas extra** — activa `apache-auth`, `nginx-http-auth`, `postfix` o `dovecot` sólo si esos servicios existen en la máquina.
13. **Arrancar el servicio** — responde `s` para habilitarlo en el arranque y levantarlo ya.

## 5. Qué escribe el script

Crea `/etc/fail2ban/jail.local`. Ejemplo:

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

Nunca edita `jail.conf`: así las actualizaciones del paquete no sobrescriben tus decisiones. Si ya existía un `jail.local`, guarda una copia con fecha en `/etc/fail2ban/backups/`.

## 6. Verificar que funciona

```bash
sudo systemctl status fail2ban
sudo fail2ban-client status
sudo fail2ban-client status sshd
sudo tail -f /var/log/fail2ban.log
```

Para probar de forma segura desde una **segunda** máquina (nunca desde tu única sesión SSH):

```bash
ssh usuario_incorrecto@TU_SERVIDOR   # repite 6 veces
sudo fail2ban-client status sshd
```

Deberías ver la IP de prueba en `Banned IP List`. Para desbanearla:

```bash
sudo fail2ban-client set sshd unbanip IP_DE_PRUEBA
```

## 7. Solución de problemas

| Síntoma | Causa | Solución |
|---|---|---|
| `No file(s) found` | `logpath` equivocado | Revisa `journalctl -u ssh` o `/var/log/auth.log` y vuelve a ejecutar el script |
| `No failures found for the given jail` | servicio parado | `sudo systemctl restart fail2ban` |
| Tu IP fue baneada | IP ausente en `ignoreip` | Añádela y ejecuta `sudo fail2ban-client reload` |
| Falla `banaction` | backend de firewall distinto | Cambia `banaction` al firewall que usas de verdad |
| No banea nada | puerto erróneo o `maxretry` alto | Confirma el puerto SSH y baja `maxretry` |

## 8. Notas por distribución

| Familia | Comando que usa el script |
|---|---|
| Debian/Ubuntu | `apt-get update && apt-get install -y fail2ban` |
| RHEL/Rocky/Alma | `dnf install -y epel-release` y luego `dnf install -y fail2ban` |
| Fedora | `dnf install -y fail2ban` |
| openSUSE | `zypper --non-interactive install -y fail2ban` |
| Alpine | `apk add --no-cache fail2ban` |
| Arch/Manjaro | `pacman -Sy --noconfirm fail2ban` |
| Void | `xbps-install -Sy fail2ban` |
| Gentoo | `emerge --noreplace net-analyzer/fail2ban` |
| Solus | `eopkg install -y fail2ban` |
| NixOS | `services.fail2ban.enable = true;` en `configuration.nix` |
| Slackware | compilar con `sbopkg -i fail2ban` |

## 9. Espejos y releases

El repositorio se sincroniza en ambos sentidos: un push a GitHub lo copia a GitLab mediante GitHub Actions, y un push a GitLab lo copia a GitHub mediante GitLab CI. Ninguno de los dos fuerza el historial. Consulta [MIRROR_VERIFICATION.md](MIRROR_VERIFICATION.md).

Para crear el ZIP de release:

```bash
make release
```
