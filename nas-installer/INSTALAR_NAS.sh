#!/usr/bin/env bash
# =============================================================================
#  INSTALAR_NAS.sh
#  Script maestro — ejecutar UNA sola vez en la laptop vieja
#
#  USO:
#    1. Copiá toda la carpeta "nas-installer" a la laptop (por USB o red)
#    2. Abrí una terminal en la laptop
#    3. Ejecutá:
#         cd nas-installer
#         sudo bash INSTALAR_NAS.sh
#
#  El script hace TODO solo y al final te dice exactamente qué hacer
#  en tu PC principal (Windows/macOS/Linux).
# =============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Colores ───────────────────────────────────────────────────────────────────
R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'
B='\033[0;34m'; C='\033[0;36m'; W='\033[1;37m'; N='\033[0m'

ok()   { echo -e "${G}  [✓]${N} $*"; }
info() { echo -e "${B}  [·]${N} $*"; }
warn() { echo -e "${Y}  [!]${N} $*"; }
err()  { echo -e "${R}  [✗]${N} $*"; exit 1; }
step() { echo -e "\n${W}══════════════════════════════════════════${N}"; \
         echo -e "${C}  $*${N}"; \
         echo -e "${W}══════════════════════════════════════════${N}"; }

# ── Verificaciones previas ────────────────────────────────────────────────────
[[ $EUID -ne 0 ]] && err "Ejecutá como root:  sudo bash INSTALAR_NAS.sh"
[[ ! -f "$SCRIPT_DIR/pasos/01_sistema.sh" ]] && err "Ejecutá desde dentro de la carpeta nas-installer"

clear
echo -e "${W}"
echo "  ╔════════════════════════════════════════════════╗"
echo "  ║     NAS INTELIGENTE — INSTALADOR AUTOMÁTICO    ║"
echo "  ║          Laptop vieja → Servidor NAS            ║"
echo "  ╚════════════════════════════════════════════════╝"
echo -e "${N}"
echo "  Este script configura todo automáticamente."
echo "  Tiempo estimado: 5 a 15 minutos según tu conexión."
echo ""
read -rp "  ¿Continuamos? [S/n]: " respuesta
[[ "${respuesta,,}" == "n" ]] && echo "  Cancelado." && exit 0

# ── Ejecutar pasos en orden ───────────────────────────────────────────────────
for paso in "$SCRIPT_DIR"/pasos/0*.sh; do
    bash "$paso" "$SCRIPT_DIR" || err "Falló el paso: $(basename "$paso")"
done

# ── Leer IP detectada y usuario ───────────────────────────────────────────────
IP_NAS=$(cat /tmp/nas_ip 2>/dev/null || hostname -I | awk '{print $1}')
NAS_USER="nasuser"

# ── Resumen final para el usuario ─────────────────────────────────────────────
clear
echo -e "${W}"
echo "  ╔════════════════════════════════════════════════╗"
echo "  ║         ✓  INSTALACIÓN COMPLETADA              ║"
echo "  ╚════════════════════════════════════════════════╝"
echo -e "${N}"
echo -e "${G}  La laptop ya está funcionando como NAS.${N}"
echo ""
echo -e "${Y}  ┌─────────────────────────────────────────────┐"
echo -e "  │   DATOS DE TU NAS                           │"
echo -e "  │                                             │"
echo -e "  │   IP del NAS   : ${W}${IP_NAS}${Y}                │"
echo -e "  │   Usuario      : ${W}${NAS_USER}${Y}               │"
echo -e "  │   Panel web    : ${W}http://${IP_NAS}:8080${Y}  │"
echo -e "  └─────────────────────────────────────────────┘${N}"
echo ""

echo -e "${C}════════════════════════════════════════════════════"
echo -e "  QUÉ HACER AHORA EN TU PC PRINCIPAL (Windows)"
echo -e "════════════════════════════════════════════════════${N}"
echo ""
echo -e "  ${W}1. ACCEDER A LOS ARCHIVOS DEL NAS${N}"
echo "     Abrí el Explorador de archivos y en la barra"
echo "     de direcciones escribí exactamente:"
echo -e "     ${Y}  \\\\${IP_NAS}\\AlmacenNAS${N}"
echo ""
echo -e "  ${W}2. MAPEAR COMO UNIDAD PERMANENTE (recomendado)${N}"
echo "     Click derecho en 'Este equipo'"
echo "     → 'Conectar a unidad de red...'"
echo -e "     → Letra: ${Y}Z:${N}   Carpeta: ${Y}\\\\${IP_NAS}\\AlmacenNAS${N}"
echo "     → Tildá 'Conectar de nuevo al iniciar sesión'"
echo ""
echo -e "  ${W}3. PANEL WEB (desde cualquier navegador)${N}"
echo -e "     ${Y}  http://${IP_NAS}:8080${N}"
echo "     Podés subir, bajar y eliminar archivos desde ahí."
echo ""
echo -e "  ${W}4. CONFIGURAR RESPALDO AUTOMÁTICO${N}"
echo "     Para que la laptop respalde tu PC automáticamente:"
echo "     a) En tu PC Windows, compartí la carpeta que querés respaldar:"
echo "        Click derecho → Propiedades → Compartir → Compartir..."
echo "        Anotá la ruta de red que aparece (ej: \\\\MIPC\\Documentos)"
echo "     b) Editá en la laptop el archivo:"
echo -e "        ${Y}  /home/nasuser/backup_sync.py${N}"
echo "        Cambiá la línea ORIGEN por la ruta de tu carpeta compartida"
echo "     c) Reiniciá el servicio:"
echo -e "        ${Y}  sudo systemctl restart backup-inteligente${N}"
echo ""
echo -e "  ${W}5. ACCESO REMOTO A LA LAPTOP (opcional)${N}"
echo "     Desde tu PC, abrí PowerShell o CMD y escribí:"
echo -e "     ${Y}  ssh nasuser@${IP_NAS}${N}"
echo "     (Contraseña: la que elegiste para nasuser)"
echo ""
echo -e "${C}════════════════════════════════════════════════════${N}"
echo ""
echo "  Los logs del sistema están en:"
echo -e "  ${Y}  /home/nasuser/backup.log${N}   (respaldos)"
echo -e "  ${Y}  sudo journalctl -u nasweb -f${N}  (panel web)"
echo ""
echo -e "${G}  ¡La laptop ya está lista! Podés cerrar esta terminal.${N}"
echo ""
