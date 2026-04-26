#!/usr/bin/env bash
# =============================================================================
# setup.sh — Instalación automatizada del NAS inteligente
#
# Ejecutar como root desde la carpeta raíz del repositorio:
#   sudo bash scripts/setup.sh
#
# Qué hace este script:
#   1. Actualiza el sistema
#   2. Instala Samba, SSH, cifs-utils, Python 3 y dependencias
#   3. Crea el usuario nasuser si no existe
#   4. Crea las carpetas necesarias con los permisos correctos
#   5. Aplica la configuración de Samba
#   6. Instala los servicios systemd de backup y panel web
#   7. Configura el firewall UFW
#   8. Habilita e inicia todos los servicios
# =============================================================================

set -euo pipefail

# ── Colores para output ───────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Sin color

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()      { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ── Verificaciones previas ────────────────────────────────────────────────────
[[ $EUID -ne 0 ]] && error "Este script debe ejecutarse como root: sudo bash scripts/setup.sh"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
info "Directorio del repositorio: $REPO_DIR"

# ── Variables configurables ───────────────────────────────────────────────────
NAS_USER="nasuser"
NAS_HOME="/home/$NAS_USER"
COMPARTIDO="$NAS_HOME/Compartido"
BACKUPS="$COMPARTIDO/Backups"

echo ""
echo "============================================================"
echo "   NAS Inteligente — Instalación automatizada"
echo "============================================================"
echo ""

# ── 1. Actualizar sistema ─────────────────────────────────────────────────────
info "Actualizando lista de paquetes..."
apt-get update -qq
ok "Sistema actualizado."

# ── 2. Instalar paquetes ──────────────────────────────────────────────────────
info "Instalando paquetes necesarios..."
apt-get install -y -qq \
    samba \
    openssh-server \
    cifs-utils \
    python3 \
    python3-pip \
    ufw \
    lm-sensors \
    git
ok "Paquetes instalados."

info "Instalando dependencias Python..."
pip3 install -q watchdog flask psutil
ok "Dependencias Python instaladas."

# ── 3. Crear usuario nasuser si no existe ─────────────────────────────────────
if id "$NAS_USER" &>/dev/null; then
    info "Usuario '$NAS_USER' ya existe. Omitiendo creación."
else
    info "Creando usuario '$NAS_USER'..."
    adduser --disabled-password --gecos "" "$NAS_USER"
    ok "Usuario '$NAS_USER' creado. Establece su contraseña con: passwd $NAS_USER"
fi

# ── 4. Crear estructura de carpetas ──────────────────────────────────────────
info "Creando carpetas del NAS..."
mkdir -p "$COMPARTIDO" "$BACKUPS" /mnt/pc_backup
chmod 777 "$COMPARTIDO"
chown -R "$NAS_USER:$NAS_USER" "$NAS_HOME"
ok "Carpetas creadas: $COMPARTIDO, $BACKUPS"

# ── 5. Copiar scripts Python ──────────────────────────────────────────────────
info "Copiando scripts al directorio del usuario..."
cp "$REPO_DIR/scripts/backup_sync.py" "$NAS_HOME/"
cp "$REPO_DIR/scripts/monitor.py"     "$NAS_HOME/"
cp "$REPO_DIR/panel/nas_web.py"       "$NAS_HOME/"
chown "$NAS_USER:$NAS_USER" "$NAS_HOME"/*.py
ok "Scripts copiados a $NAS_HOME."

# ── 6. Configurar Samba ───────────────────────────────────────────────────────
info "Configurando Samba..."
SMB_CONF="/etc/samba/smb.conf"
SNIPPET="$REPO_DIR/config/smb.conf.snippet"

if grep -q "\[AlmacenNAS\]" "$SMB_CONF"; then
    warn "La sección [AlmacenNAS] ya existe en smb.conf. Omitiendo."
else
    cat "$SNIPPET" >> "$SMB_CONF"
    ok "Configuración de Samba aplicada."
fi

systemctl restart smbd
systemctl enable smbd
ok "Samba en marcha."

# ── 7. Habilitar SSH ──────────────────────────────────────────────────────────
info "Habilitando SSH..."
systemctl enable ssh
systemctl start ssh
ok "SSH habilitado."

# ── 8. Instalar servicios systemd ─────────────────────────────────────────────
info "Instalando servicios systemd..."
cp "$REPO_DIR/services/backup-inteligente.service" /etc/systemd/system/
cp "$REPO_DIR/services/nasweb.service"             /etc/systemd/system/

systemctl daemon-reload

systemctl enable backup-inteligente.service
systemctl start  backup-inteligente.service

systemctl enable nasweb.service
systemctl start  nasweb.service

ok "Servicios instalados y en marcha."

# ── 9. Configurar UFW ─────────────────────────────────────────────────────────
info "Configurando firewall UFW..."
ufw --force reset   > /dev/null
ufw default deny incoming > /dev/null
ufw default allow outgoing > /dev/null
ufw allow 22/tcp    comment 'SSH'         > /dev/null
ufw allow 445/tcp   comment 'Samba'       > /dev/null
ufw allow 8080/tcp  comment 'Panel NAS'   > /dev/null
ufw --force enable  > /dev/null
ok "Firewall configurado."

# ── Resumen final ─────────────────────────────────────────────────────────────
IP=$(hostname -I | awk '{print $1}')
echo ""
echo "============================================================"
echo -e "   ${GREEN}Instalación completada correctamente.${NC}"
echo "============================================================"
echo ""
echo "  Carpeta compartida : $COMPARTIDO"
echo "  Panel web          : http://${IP}:8080"
echo "  Acceso Windows     : \\\\${IP}\\AlmacenNAS"
echo "  Acceso macOS/Linux : smb://${IP}/AlmacenNAS"
echo ""
echo "Pasos manuales pendientes:"
echo "  1. Edita $NAS_HOME/backup_sync.py → ajusta ORIGEN y DESTINO."
echo "  2. Edita $NAS_HOME/monitor.py     → ajusta correo y umbrales."
echo "  3. Configura /etc/netplan/*.yaml   → IP estática (ver INSTALL.md §2)."
echo "  4. Configura /etc/fstab            → montaje CIFS (ver INSTALL.md §8)."
echo ""
warn "No olvides reiniciar los servicios tras editar los scripts:"
echo "  sudo systemctl restart backup-inteligente nasweb"
echo ""
