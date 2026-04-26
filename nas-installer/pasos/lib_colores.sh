#!/usr/bin/env bash
# lib_colores.sh — colores, funciones y variables compartidas entre pasos

R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'
B='\033[0;34m'; C='\033[0;36m'; W='\033[1;37m'; N='\033[0m'

ok()   { echo -e "${G}  [✓]${N} $*"; }
info() { echo -e "${B}  [·]${N} $*"; }
warn() { echo -e "${Y}  [!]${N} $*"; }
err()  { echo -e "${R}  [✗]${N} $*"; exit 1; }
step() {
  echo -e "\n${W}══════════════════════════════════════════${N}"
  echo -e "${C}  $*${N}"
  echo -e "${W}══════════════════════════════════════════${N}"
}

# ── Detectar usuario real de la laptop ───────────────────────────────────────
# sudo guarda el usuario original en SUDO_USER
if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
    NAS_USER="$SUDO_USER"
elif [[ "$(id -u)" -ne 0 ]]; then
    NAS_USER="$(whoami)"
else
    # Primer usuario con UID >= 1000 que no sea nobody
    NAS_USER=$(awk -F: '$3>=1000 && $3<65534 && $1!="nobody" {print $1; exit}' /etc/passwd)
fi

if [[ -z "$NAS_USER" ]]; then
    echo -e "${Y}  No se detectó el usuario automáticamente.${N}"
    read -rp "  Ingresá tu nombre de usuario de Ubuntu: " NAS_USER
fi

NAS_HOME=$(eval echo "~$NAS_USER")
NAS_COMPARTIDO="$NAS_HOME/Compartido"

export NAS_USER NAS_HOME NAS_COMPARTIDO
