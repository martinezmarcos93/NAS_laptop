#!/usr/bin/env bash
SCRIPT_DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$SCRIPT_DIR/pasos/lib_colores.sh"

step "PASO 4/6 — Configurando Samba (carpeta de red)"

SMB_CONF="/etc/samba/smb.conf"

# Backup del original
[[ ! -f "${SMB_CONF}.original" ]] && cp "$SMB_CONF" "${SMB_CONF}.original" \
    && ok "Backup guardado: ${SMB_CONF}.original"

# Agregar sección si no existe
if grep -q "\[AlmacenNAS\]" "$SMB_CONF"; then
    warn "Sección [AlmacenNAS] ya existe en smb.conf. Omitiendo."
else
    info "Agregando configuración a smb.conf..."
    # Usar variable expandida porque el path depende del usuario real
    cat >> "$SMB_CONF" << SAMBA

# ── NAS Inteligente ── configurado automáticamente ────────────────────────────
[AlmacenNAS]
   comment = Almacenamiento NAS — $(hostname)
   path = $NAS_COMPARTIDO
   browseable = yes
   read only = no
   guest ok = yes
   create mask = 0755
   directory mask = 0755
   force user = $NAS_USER
SAMBA
    ok "Sección [AlmacenNAS] agregada (carpeta: $NAS_COMPARTIDO)."
fi

# Usuario Samba con la misma contraseña del sistema (o una genérica)
info "Configurando usuario Samba '$NAS_USER'..."
# Intentar obtener la contraseña actual del usuario para Samba
# Como no la conocemos, usamos una contraseña de Samba separada
# El usuario puede cambiarla con: sudo smbpasswd -a $NAS_USER
(echo "nas1234"; echo "nas1234") | smbpasswd -s -a "$NAS_USER" 2>/dev/null || true
ok "Usuario Samba '$NAS_USER' configurado."
warn "Contraseña Samba: nas1234 — cambiala con: sudo smbpasswd -a $NAS_USER"

# Iniciar Samba
systemctl enable smbd --quiet
systemctl restart smbd
sleep 1
systemctl is-active --quiet smbd \
    && ok "Samba activo y en marcha." \
    || warn "Samba no inició. Revisá con: sudo systemctl status smbd"
