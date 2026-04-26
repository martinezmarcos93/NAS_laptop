#!/usr/bin/env bash
SCRIPT_DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$SCRIPT_DIR/pasos/lib_colores.sh"

step "PASO 1/6 — Actualizando sistema e instalando paquetes"

info "Actualizando lista de paquetes..."
apt-get update -qq
ok "Lista actualizada."

info "Instalando paquetes del sistema..."
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    samba openssh-server cifs-utils python3 python3-pip \
    ufw lm-sensors git curl net-tools unattended-upgrades
ok "Paquetes instalados."

info "Instalando librerías Python..."
pip3 install -q --break-system-packages watchdog flask psutil 2>/dev/null \
  || pip3 install -q watchdog flask psutil
ok "watchdog, flask, psutil instalados."

info "Configurando actualizaciones automáticas de seguridad..."
echo 'Unattended-Upgrade::Automatic-Reboot "false";' \
  >> /etc/apt/apt.conf.d/50unattended-upgrades 2>/dev/null || true
ok "Actualizaciones de seguridad configuradas."
