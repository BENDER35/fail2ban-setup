#!/usr/bin/env bash
#
# install_fail2ban.sh - Instalador/configurador interactivo de fail2ban.
#
# Soporta (detección automática):
#   Debian/Ubuntu/Linux Mint/Raspbian (apt)
#   RHEL/CentOS/Rocky/Alma/Fedora (dnf/yum)
#   openSUSE/SLES (zypper)
#   Alpine (apk)
#   Arch/Manjaro (pacman)
#   Void Linux (xbps)
#   Gentoo (emerge)
#   Solus (eopkg)
#   Slackware (sbopkg, sólo guía manual)
#   Cualquier otra distribución: modo manual / --dry-run
#
# Uso:
#   sudo ./install_fail2ban.sh
#   ./install_fail2ban.sh --dry-run          # no escribe nada
#   sudo ./install_fail2ban.sh --yes         # acepta valores por defecto
#
set -Eeuo pipefail

readonly SCRIPT_NAME="${0##*/}"
readonly VERSION="1.0.0"
readonly CONFIG_FILE="/etc/fail2ban/jail.local"
readonly BACKUP_DIR="/etc/fail2ban/backups"

AUTO=0
DRY_RUN=0
OS_ID="desconocido"
OS_PRETTY="desconocido"
PKG_MGR=""

log()  { printf '[*] %s\n' "$*"; }
warn() { printf '[!] %s\n' "$*" >&2; }
die()  { printf '[x] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<EOF
$SCRIPT_NAME v$VERSION

Instalador/configurador interactivo de fail2ban.

Instala fail2ban si no está presente y, esté o no instalado, permite
configurarlo interactivamente parámetro a parámetro.

Opciones:
  -y, --yes          No pregunta: usa los valores por defecto.
  -n, --dry-run      Simula la instalación y muestra la configuración; no escribe.
  -h, --help         Muestra esta ayuda.
  -v, --version      Muestra la versión.

Ejemplos:
  sudo $SCRIPT_NAME
  $SCRIPT_NAME --dry-run --yes
EOF
}

parse_args() {
  while (($#)); do
    case "$1" in
      -y|--yes) AUTO=1; shift ;;
      -n|--dry-run) DRY_RUN=1; shift ;;
      -h|--help) usage; exit 0 ;;
      -v|--version) printf '%s %s\n' "$SCRIPT_NAME" "$VERSION"; exit 0 ;;
      *) die "Opción desconocida: $1 (usa --help)" ;;
    esac
  done
}

require_root() {
  [[ ${EUID:-$(id -u)} -eq 0 ]] || die "Este script necesita permisos de root (ejecútalo con sudo)."
}

run_step() {
  if (( DRY_RUN )); then
    printf '[dry-run] '
    printf '%q ' "$@"
    printf '\n'
  else
    "$@"
  fi
}

ask() {
  local question="$1" default="${2-}" answer=""
  if (( AUTO )); then
    # La traza va a stderr para no contaminar el valor devuelto por $(ask ...).
    printf '%s [%s] -> %s\n' "$question" "$default" "$default" >&2
    printf '%s' "$default"
    return 0
  fi
  if [[ -n "$default" ]]; then
    read -r -p "$question [$default]: " answer || answer=""
    printf '%s' "${answer:-$default}"
  else
    read -r -p "$question: " answer || answer=""
    printf '%s' "$answer"
  fi
}

ask_yn() {
  local question="$1" default="$2" answer
  answer="$(ask "$question (s/n)" "$default")"
  case "${answer,,}" in
    s|si|sí|y|yes|1) return 0 ;;
    n|no|0) return 1 ;;
    *) warn "Respuesta no válida. Usa s o n."; ask_yn "$question" "$default" ;;
  esac
}

os_release_value() {
  # Se lee con sed en lugar de "source" para no sobrescribir variables
  # del script como VERSION (declarada como readonly).
  sed -n "s/^$1=\"\?\([^\"]*\)\"\?.*/\1/p" /etc/os-release 2>/dev/null | head -n1
}

detect_os() {
  if [[ -r /etc/os-release ]]; then
    OS_ID="$(os_release_value ID)"
    OS_PRETTY="$(os_release_value PRETTY_NAME)"
    OS_ID="${OS_ID:-desconocido}"
    OS_PRETTY="${OS_PRETTY:-$OS_ID}"
  else
    OS_ID="$(uname -s | tr '[:upper:]' '[:lower:]')"
    OS_PRETTY="$(uname -sr)"
  fi
  log "Sistema detectado: $OS_PRETTY ($OS_ID)"
}

detect_package_manager() {
  if [[ "$OS_ID" == "nixos" ]]; then
    warn "NixOS requiere una declaración en configuration.nix; se mostrará la configuración sugerida."
    return 0
  fi
  local manager
  for manager in apt-get dnf yum zypper apk pacman xbps-install emerge eopkg sbopkg; do
    if command -v "$manager" >/dev/null 2>&1; then
      PKG_MGR="$manager"
      log "Gestor de paquetes detectado: $manager"
      return 0
    fi
  done
  warn "No se detectó un gestor de paquetes soportado."
}

fail2ban_installed() {
  command -v fail2ban-client >/dev/null 2>&1 && return 0
  if command -v dpkg-query >/dev/null 2>&1 && dpkg-query -W -f='${Status}' fail2ban 2>/dev/null | grep -q 'install ok installed'; then
    return 0
  fi
  if command -v rpm >/dev/null 2>&1 && rpm -q fail2ban >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

install_fail2ban() {
  if fail2ban_installed; then
    log "fail2ban ya está instalado; se omite la instalación."
    return 0
  fi

  case "$PKG_MGR" in
    apt-get)
      run_step env DEBIAN_FRONTEND=noninteractive apt-get update
      run_step env DEBIAN_FRONTEND=noninteractive apt-get install -y fail2ban
      ;;
    dnf|yum)
      # EPEL es necesario en RHEL/CentOS/Rocky/Alma; en Fedora el paquete ya está disponible.
      if [[ "$OS_ID" =~ ^(rhel|centos|rocky|almalinux|scientific|ol|amzn)$ ]]; then
        run_step "$PKG_MGR" install -y epel-release || warn "No se pudo instalar EPEL; se intentará con los repositorios actuales."
      fi
      run_step "$PKG_MGR" install -y fail2ban
      ;;
    zypper)
      run_step zypper --non-interactive refresh
      run_step zypper --non-interactive install -y fail2ban
      ;;
    apk)
      run_step apk add --no-cache fail2ban
      ;;
    pacman)
      run_step pacman -Sy --noconfirm fail2ban
      ;;
    xbps-install)
      run_step xbps-install -Sy fail2ban
      ;;
    emerge)
      run_step emerge --noreplace net-analyzer/fail2ban
      ;;
    eopkg)
      run_step eopkg install -y fail2ban
      ;;
    sbopkg)
      warn "Slackware: usa sbopkg para construir fail2ban desde SlackBuilds:"
      warn "  sbopkg -i fail2ban"
      ;;
    *)
      warn "Instalación manual necesaria para $OS_PRETTY."
      cat >&2 <<'EOF'
  Debian/Ubuntu : sudo apt update && sudo apt install -y fail2ban
  RHEL/Rocky    : sudo dnf install -y epel-release && sudo dnf install -y fail2ban
  openSUSE      : sudo zypper install -y fail2ban
  Alpine        : sudo apk add --no-cache fail2ban
  Arch          : sudo pacman -S --noconfirm fail2ban
  Void          : sudo xbps-install -Sy fail2ban
  Gentoo        : sudo emerge net-analyzer/fail2ban
  NixOS         : services.fail2ban.enable = true; (en /etc/nixos/configuration.nix)
EOF
      (( DRY_RUN )) || die "No se puede instalar automáticamente en este sistema. Instala fail2ban manualmente y vuelve a ejecutar el script."
      ;;
  esac
}

detect_backend() {
  if [[ -d /run/systemd/system ]] && command -v journalctl >/dev/null 2>&1; then
    printf 'systemd'
  else
    printf 'polling'
  fi
}

detect_logpath() {
  local backend="$1" candidate
  if [[ "$backend" == "systemd" ]]; then
    printf 'journal'
    return 0
  fi
  for candidate in /var/log/auth.log /var/log/secure /var/log/messages; do
    [[ -e "$candidate" ]] && { printf '%s' "$candidate"; return 0; }
  done
  printf '/var/log/auth.log'
}

detect_banaction() {
  if command -v nft >/dev/null 2>&1 && systemctl is-active --quiet nftables 2>/dev/null; then
    printf 'nftables'
  elif command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -qi '^Status: active'; then
    printf 'ufw'
  elif command -v firewall-cmd >/dev/null 2>&1 && firewall-cmd --state 2>/dev/null | grep -qi '^running'; then
    if [[ -f /etc/fail2ban/action.d/firewallcmd-ipset.conf ]]; then
      printf 'firewallcmd-ipset'
    else
      printf 'firewallcmd-rich-rules'
    fi
  elif command -v iptables >/dev/null 2>&1; then
    printf 'iptables'
  else
    printf 'iptables'
  fi
}

validate_number() {
  [[ "$1" =~ ^[0-9]+$ ]] || die "'$2' debe ser un número entero."
}

validate_duration() {
  [[ "$1" =~ ^[0-9]+[smhd]?$ ]] || die "'$2' debe ser como 600, 10m, 1h o 1d."
}

collect_config() {
  local backend logpath banaction ssh_port ssh_log default_ignore
  local ip answer

  echo
  log "Configuración interactiva (pulsa Enter para aceptar el valor entre corchetes)."

  default_ignore="$(ask 'IPs/redes a ignorar (separadas por espacios)' '127.0.0.1/8 ::1')"
  CFG_IGNOREIP="$default_ignore"

  answer="$(ask 'Tiempo de baneo (ej. 10m, 1h, 1d)' '1h')"
  validate_duration "$answer" 'bantime'; CFG_BANTIME="$answer"

  answer="$(ask 'Ventana de búsqueda (ej. 10m)' '10m')"
  validate_duration "$answer" 'findtime'; CFG_FINDTIME="$answer"

  answer="$(ask 'Intentos fallidos antes de banear' '5')"
  validate_number "$answer" 'maxretry'; CFG_MAXRETRY="$answer"

  banaction="$(detect_banaction)"
  CFG_BANACTION="$(ask 'Acción de banneo (iptables/nftables/ufw/firewallcmd-ipset/firewallcmd-rich-rules)' "$banaction")"

  backend="$(detect_backend)"
  CFG_BACKEND="$(ask 'Backend de logs (systemd/polling)' "$backend")"

  logpath="$(detect_logpath "$backend")"
  CFG_LOGPATH="$(ask 'Ruta del log de SSH (usa "journal" con backend systemd)' "$logpath")"

  ssh_port="$(ask 'Puerto SSH a proteger' '22')"
  validate_number "$ssh_port" 'puerto SSH'
  (( ssh_port >= 1 && ssh_port <= 65535 )) || die "El puerto SSH debe estar entre 1 y 65535."
  CFG_SSHPORT="$ssh_port"

  if ask_yn '¿Activar la jaula [sshd]?' 's'; then
    CFG_SSHD_ENABLED='true'
    answer="$(ask 'Maxretry específico para SSH (vacío = usar el general)' '')"
    if [[ -n "$answer" ]]; then
      validate_number "$answer" 'maxretry de sshd'
      CFG_SSHD_MAXRETRY="$answer"
    else
      CFG_SSHD_MAXRETRY=''
    fi
  else
    CFG_SSHD_ENABLED='false'
    CFG_SSHD_MAXRETRY=''
  fi

  CFG_DESTEMAIL="$(ask 'Correo para avisos (vacío = no enviar correos)' '')"
  if [[ -n "$CFG_DESTEMAIL" ]]; then
    CFG_SENDERNAME="$(ask 'Nombre del remitente' 'Fail2Ban')"
    CFG_MTA="$(ask 'Agente de correo (sendmail/mail)' 'sendmail')"
    CFG_ACTION='%(action_mwl)s'
  else
    CFG_SENDERNAME='Fail2Ban'
    CFG_MTA='sendmail'
    CFG_ACTION='%(action_)s'
  fi

  CFG_LOGLEVEL="$(ask 'Nivel de log (CRITICAL/ERROR/WARNING/NOTICE/INFO/DEBUG)' 'INFO')"

  CFG_APACHE='false'; CFG_APACHE_LOG='/var/log/apache2/error.log'
  if ask_yn '¿Activar la jaula [apache-auth]?' 'n'; then
    CFG_APACHE='true'
    CFG_APACHE_LOG="$(ask 'Ruta del log de errores de Apache' "$CFG_APACHE_LOG")"
  fi

  CFG_NGINX='false'; CFG_NGINX_LOG='/var/log/nginx/error.log'
  if ask_yn '¿Activar la jaula [nginx-http-auth]?' 'n'; then
    CFG_NGINX='true'
    CFG_NGINX_LOG="$(ask 'Ruta del log de errores de Nginx' "$CFG_NGINX_LOG")"
  fi

  CFG_POSTFIX='false'; CFG_POSTFIX_LOG='/var/log/mail.log'
  if ask_yn '¿Activar la jaula [postfix]?' 'n'; then
    CFG_POSTFIX='true'
    CFG_POSTFIX_LOG="$(ask 'Ruta del log de Postfix' "$CFG_POSTFIX_LOG")"
  fi

  CFG_DOVECOT='false'; CFG_DOVECOT_LOG='/var/log/maillog'
  if ask_yn '¿Activar la jaula [dovecot]?' 'n'; then
    CFG_DOVECOT='true'
    CFG_DOVECOT_LOG="$(ask 'Ruta del log de Dovecot' "$CFG_DOVECOT_LOG")"
  fi

  CFG_START_SERVICE='true'
  if ! ask_yn '¿Habilitar y arrancar el servicio fail2ban ahora?' 's'; then
    CFG_START_SERVICE='false'
  fi

  for ip in $CFG_IGNOREIP; do
    if [[ "$ip" != *'/'* && "$ip" != '::1' && ! "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      warn "'$ip' no parece una IP o red; fail2ban puede rechazarla."
    fi
  done
}

render_config() {
  cat <<EOF
# Gestionado por $SCRIPT_NAME v$VERSION
# Generado el: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
# No edites /etc/fail2ban/jail.conf; edita este archivo.

[DEFAULT]
ignoreip = $CFG_IGNOREIP
bantime  = $CFG_BANTIME
findtime = $CFG_FINDTIME
maxretry = $CFG_MAXRETRY
backend  = $CFG_BACKEND
banaction = $CFG_BANACTION
destemail = $CFG_DESTEMAIL
sendername = $CFG_SENDERNAME
mta = $CFG_MTA
action = $CFG_ACTION
loglevel = $CFG_LOGLEVEL

[sshd]
enabled  = $CFG_SSHD_ENABLED
port     = $CFG_SSHPORT
$( [[ -n "$CFG_LOGPATH" ]] && printf 'logpath  = %s\n' "$CFG_LOGPATH" )
$( [[ -n "$CFG_SSHD_MAXRETRY" ]] && printf 'maxretry = %s\n' "$CFG_SSHD_MAXRETRY" )

[apache-auth]
enabled = $CFG_APACHE
$( [[ "$CFG_APACHE" == 'true' ]] && printf 'logpath = %s\n' "$CFG_APACHE_LOG" )

[nginx-http-auth]
enabled = $CFG_NGINX
$( [[ "$CFG_NGINX" == 'true' ]] && printf 'logpath = %s\n' "$CFG_NGINX_LOG" )

[postfix]
enabled = $CFG_POSTFIX
$( [[ "$CFG_POSTFIX" == 'true' ]] && printf 'logpath = %s\n' "$CFG_POSTFIX_LOG" )

[dovecot]
enabled = $CFG_DOVECOT
$( [[ "$CFG_DOVECOT" == 'true' ]] && printf 'logpath = %s\n' "$CFG_DOVECOT_LOG" )
EOF
}

write_config() {
  local tmp
  tmp="$(mktemp)"
  render_config > "$tmp"

  if (( DRY_RUN )); then
    echo
    log "Contenido que se escribiría en $CONFIG_FILE:"
    echo "------------------------------------------------------------"
    cat "$tmp"
    echo "------------------------------------------------------------"
    rm -f "$tmp"
    return 0
  fi

  mkdir -p "$(dirname "$CONFIG_FILE")" "$BACKUP_DIR"
  if [[ -f "$CONFIG_FILE" ]]; then
    local backup="$BACKUP_DIR/jail.local.$(date +%Y%m%d%H%M%S).bak"
    cp -a "$CONFIG_FILE" "$backup"
    log "Copia de seguridad guardada en $backup"
  fi
  install -m 0644 "$tmp" "$CONFIG_FILE"
  rm -f "$tmp"
  log "Configuración escrita en $CONFIG_FILE"
}

start_service() {
  [[ "$CFG_START_SERVICE" == 'true' ]] || { log "Servicio no iniciado (elección del usuario)."; return 0; }

  if (( DRY_RUN )); then
    printf '[dry-run] Se habilitaría y arrancaría el servicio fail2ban\n'
    return 0
  fi

  if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
    run_step systemctl enable --now fail2ban
  elif command -v rc-service >/dev/null 2>&1; then
    run_step rc-update add fail2ban default
    run_step rc-service fail2ban start
  elif command -v service >/dev/null 2>&1; then
    run_step service fail2ban start
  else
    warn "No se detectó un gestor de servicios compatible. Arranca fail2ban manualmente."
    return 0
  fi
  log "Servicio fail2ban habilitado/arrancado."
}

show_status() {
  (( DRY_RUN )) && return 0
  command -v fail2ban-client >/dev/null 2>&1 || return 0
  echo
  log "Estado de fail2ban:"
  fail2ban-client status 2>&1 || warn "fail2ban-client no pudo consultar el estado."
  if [[ "$CFG_SSHD_ENABLED" == 'true' ]]; then
    echo
    log "Estado de la jaula sshd:"
    fail2ban-client status sshd 2>&1 || warn "La jaula sshd aún no está activa."
  fi
}

main() {
  parse_args "$@"
  log "$SCRIPT_NAME v$VERSION"
  detect_os
  detect_package_manager

  if (( DRY_RUN )); then
    log "Modo simulación: no se instalará ni escribirá nada."
  else
    require_root
  fi

  install_fail2ban
  collect_config
  write_config
  start_service
  show_status

  echo
  log "Finalizado. Para revisar: sudo fail2ban-client status"
  log "Para ver el log: sudo tail -f /var/log/fail2ban.log"
}

main "$@"
