# v1.0.0

Primera versión publicada.

- Instalador interactivo de fail2ban con detección de gestor de paquetes (apt, dnf/yum, zypper, apk, pacman, xbps, emerge, eopkg, sbopkg).
- Configuración parámetro a parámetro de `/etc/fail2ban/jail.local` con copia de seguridad previa.
- Soporte para jaulas `sshd`, `apache-auth`, `nginx-http-auth`, `postfix` y `dovecot`.
- Modos `--dry-run` y `--yes` para pruebas y automatización.
- Documentación didáctica en español, inglés y bable/asturiano.
- Espejo automático bidireccional GitHub ⇄ GitLab sin force-push.
- Release distribuida como ZIP generado con `git archive`.
