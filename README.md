# fail2ban-setup

Instalador y configurador interactivo de **fail2ban** para GNU/Linux, con documentación didáctica en **español**, **inglés** y **bable/asturiano**, espejo automático bidireccional entre GitHub y GitLab y releases distribuidas en ZIP.

> El script detecta si fail2ban ya está instalado. Si no lo está, lo instala con el gestor de paquetes del sistema; después pregunta **parámetro por parámetro** y genera `/etc/fail2ban/jail.local` respetando la configuración previa mediante una copia de seguridad.

## Inicio rápido

```bash
git clone https://github.com/BENDER35/fail2ban-setup.git
cd fail2ban-setup
chmod +x install_fail2ban.sh
sudo ./install_fail2ban.sh
```

Simular sin escribir nada:

```bash
./install_fail2ban.sh --dry-run
```

Aceptar todos los valores por defecto (útil para contenedores o automatización):

```bash
sudo ./install_fail2ban.sh --yes
```

## Parámetros que pregunta el script

| Parámetro | Valor por defecto | Descripción |
|---|---|---|
| `ignoreip` | `127.0.0.1/8 ::1` | IPs/redes que nunca se banean |
| `bantime` | `1h` | Duración del baneo |
| `findtime` | `10m` | Ventana en la que se cuentan los fallos |
| `maxretry` | `5` | Fallos permitidos antes de banear |
| `banaction` | detectada | `iptables`, `nftables`, `ufw`, `firewallcmd-*` |
| `backend` | detectado | `systemd` (journal) o `polling` (archivos) |
| `logpath` | detectado | Ruta del log de SSH; `journal` con systemd |
| `port` | `22` | Puerto SSH protegido |
| `sshd.maxretry` | vacío | Sobrescribe el general sólo para SSH |
| `destemail` | vacío | Si se indica, activa `action_mwl` (requiere MTA) |
| `loglevel` | `INFO` | Nivel de detalle del log |
| Jails extra | desactivadas | `apache-auth`, `nginx-http-auth`, `postfix`, `dovecot` |

## Compatibilidad

El script detecta automáticamente estos gestores: `apt-get`, `dnf`, `yum`, `zypper`, `apk`, `pacman`, `xbps-install`, `emerge`, `eopkg` y `sbopkg`. Si la distribución no está en la lista, muestra los comandos manuales y permite generar la configuración con `--dry-run`. En NixOS se sugiere `services.fail2ban.enable = true;`.

No existe una única forma de empaquetar fail2ban en «todas» las distribuciones Linux; por eso el script combina detección automática, rutas alternativas y una guía manual explícita en lugar de asumir un único gestor.

## Documentación didáctica

- [Guía en español](docs/guide-es.md)
- [English guide](docs/guide-en.md)
- [Guía en bable/asturianu](docs/guide-ast.md)
- [Verificación del mirror](docs/MIRROR_VERIFICATION.md)

## Repositorios y mirror

| Servicio | URL |
|---|---|
| GitHub (principal) | https://github.com/BENDER35/fail2ban-setup |
| GitLab (copia/espejo) | https://gitlab.com/BENDER_5000/fail2ban-setup |

- `.github/workflows/mirror-to-gitlab.yml`: GitHub → GitLab.
- `.gitlab-ci.yml`: GitLab → GitHub.
- Ambos usan push **sin force**: si las ramas divergen, el trabajo falla y avisa en lugar de perder historial.
- Secretos: `GITLAB_TOKEN` en GitHub Actions y `GH_TOKEN` en GitLab CI.

## Release

Las releases se publican como ZIP generado con `git archive` (sin el directorio `.git`):

```bash
make release
```

El ZIP se adjunta tanto a la release de GitHub como a la de GitLab.

## Aviso

Prueba la configuración en un entorno controlado antes de aplicarla a producción. Un `bantime` largo o un `maxretry` bajo pueden bloquear usuarios legítimos. Añade tu propia IP a `ignoreip` antes de cerrar la sesión SSH.

## Licencia

MIT. Ver [LICENSE](LICENSE).
