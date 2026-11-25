#!/usr/bin/env bash
# Pruebas rápidas sin modificar el sistema.
set -Eeuo pipefail

cd "$(dirname "$0")/.."

echo '[test] Sintaxis bash'
bash -n install_fail2ban.sh

echo '[test] --help'
./install_fail2ban.sh --help | grep -q 'Instalador/configurador interactivo'

echo '[test] --version'
./install_fail2ban.sh --version | grep -q '1.0.0'

echo '[test] --dry-run --yes'
output="$(./install_fail2ban.sh --dry-run --yes)"
grep -q '^\[DEFAULT\]' <<<"$output"
grep -q '^\[sshd\]' <<<"$output"
grep -q 'bantime' <<<"$output"
grep -q 'Modo simulación' <<<"$output"

echo '[OK] Todas las pruebas pasaron.'
