#!/usr/bin/env bash
SCRIPT_DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$SCRIPT_DIR/pasos/lib_colores.sh"

step "PASO 2/6 — Preparando carpetas y detectando red"

info "Usuario detectado: $NAS_USER (home: $NAS_HOME)"
ok "Se usará el usuario existente '$NAS_USER'. No se crea ningún usuario nuevo."

# ── Carpetas ──────────────────────────────────────────────────────────────────
info "Creando estructura de carpetas del NAS..."
mkdir -p "$NAS_COMPARTIDO/Backups"
mkdir -p "$NAS_COMPARTIDO/Documentos"
mkdir -p "$NAS_COMPARTIDO/Fotos"
mkdir -p "$NAS_COMPARTIDO/Videos"
mkdir -p /mnt/pc_backup

chmod 755 "$NAS_COMPARTIDO"
chown -R "$NAS_USER:$NAS_USER" "$NAS_COMPARTIDO"
ok "Carpetas creadas en $NAS_COMPARTIDO"

# ── Detectar IP ───────────────────────────────────────────────────────────────
info "Detectando IP de la laptop en la red local..."
IP_NAS=""
for iface in $(ip -o link show | awk -F': ' '{print $2}' | grep -vE '^lo$'); do
    ip_tmp=$(ip -4 addr show "$iface" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
    if [[ -n "$ip_tmp" && "$ip_tmp" != "127."* ]]; then
        IP_NAS="$ip_tmp"; IFACE_ACTIVA="$iface"; break
    fi
done
[[ -z "$IP_NAS" ]] && IP_NAS="(verificá con: ip a)" && warn "IP no detectada automáticamente."
[[ -n "$IFACE_ACTIVA" ]] && ok "IP: $IP_NAS — Interfaz: $IFACE_ACTIVA"
echo "$IP_NAS" > /tmp/nas_ip

# ── Archivo de datos visible para el usuario ──────────────────────────────────
cat > "$NAS_HOME/MIS_DATOS_NAS.txt" << DATOS
═══════════════════════════════════════════
  DATOS DE TU NAS — $(date '+%d/%m/%Y %H:%M')
═══════════════════════════════════════════

  Usuario de la laptop : $NAS_USER
  IP del NAS           : $IP_NAS
  Panel web            : http://$IP_NAS:8080
  Acceso desde Windows : \\\\$IP_NAS\\AlmacenNAS

  Carpeta compartida   : $NAS_COMPARTIDO
  Carpeta de backups   : $NAS_COMPARTIDO/Backups

═══════════════════════════════════════════
DATOS
chown "$NAS_USER:$NAS_USER" "$NAS_HOME/MIS_DATOS_NAS.txt"
ok "Datos guardados en $NAS_HOME/MIS_DATOS_NAS.txt"
