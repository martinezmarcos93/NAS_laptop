#!/usr/bin/env bash
SCRIPT_DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$SCRIPT_DIR/pasos/lib_colores.sh"

step "PASO 3/6 — Configurando red (IP estática) y SSH"

# ── Detectar interfaz activa ──────────────────────────────────────────────────
IFACE=""; IP_ACTUAL=""; PREFIJO="24"; GATEWAY=""

for iface in $(ip -o link show | awk -F': ' '{print $2}' | grep -vE '^lo$'); do
    ip_tmp=$(ip -4 addr show "$iface" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
    if [[ -n "$ip_tmp" && "$ip_tmp" != "127."* ]]; then
        IFACE="$iface"; IP_ACTUAL="$ip_tmp"
        PREFIJO=$(ip -4 addr show "$iface" 2>/dev/null \
                  | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+' | head -1 | cut -d'/' -f2)
        PREFIJO="${PREFIJO:-24}"
        break
    fi
done
GATEWAY=$(ip route | grep default | awk '{print $3}' | head -1)
GATEWAY="${GATEWAY:-192.168.1.1}"

if [[ -z "$IFACE" ]]; then
    warn "No se detectó interfaz activa. Saltando IP estática."
else
    ok "Interfaz: $IFACE | IP actual: $IP_ACTUAL | Gateway: $GATEWAY"
    NETPLAN_FILE="/etc/netplan/99-nas-static.yaml"
    TIPO="ethernets"; [[ "$IFACE" == wl* ]] && TIPO="wifis"

    if [[ "$TIPO" == "ethernets" ]]; then
        cat > "$NETPLAN_FILE" << YAML
# Generado por INSTALAR_NAS.sh — no editar manualmente
network:
  version: 2
  renderer: NetworkManager
  ethernets:
    ${IFACE}:
      dhcp4: no
      addresses:
        - ${IP_ACTUAL}/${PREFIJO}
      routes:
        - to: default
          via: ${GATEWAY}
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
YAML
    else
        SSID=$(iwgetid -r 2>/dev/null || echo "")
        if [[ -n "$SSID" ]]; then
            warn "WiFi detectado: '$SSID'. Necesito la contraseña para fijar la IP."
            read -rsp "  Contraseña del WiFi '$SSID' (Enter para saltar): " WIFI_PASS; echo ""
            if [[ -n "$WIFI_PASS" ]]; then
                cat > "$NETPLAN_FILE" << YAML
# Generado por INSTALAR_NAS.sh
network:
  version: 2
  renderer: NetworkManager
  wifis:
    ${IFACE}:
      dhcp4: no
      addresses:
        - ${IP_ACTUAL}/${PREFIJO}
      routes:
        - to: default
          via: ${GATEWAY}
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
      access-points:
        "${SSID}":
          password: "${WIFI_PASS}"
YAML
            else
                warn "Sin contraseña WiFi. La IP no se fijó. Podés hacerlo después manualmente."
            fi
        fi
    fi

    if [[ -f "$NETPLAN_FILE" ]]; then
        chmod 600 "$NETPLAN_FILE"
        for f in /etc/netplan/01-*.yaml /etc/netplan/50-*.yaml; do
            [[ -f "$f" ]] && mv "$f" "${f}.bak" && info "Backup: $(basename $f).bak"
        done
        netplan apply 2>/dev/null && ok "IP estática $IP_ACTUAL aplicada." \
            || warn "netplan apply con advertencias (normal). Continuando."
    fi
fi

# ── SSH ───────────────────────────────────────────────────────────────────────
info "Habilitando SSH..."
systemctl enable ssh --quiet
systemctl start ssh 2>/dev/null || systemctl restart ssh
# Deshabilitar login de root por SSH
if grep -q "^PermitRootLogin" /etc/ssh/sshd_config; then
    sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
else
    echo "PermitRootLogin no" >> /etc/ssh/sshd_config
fi
systemctl reload ssh 2>/dev/null || true
ok "SSH habilitado. Login de root deshabilitado."
