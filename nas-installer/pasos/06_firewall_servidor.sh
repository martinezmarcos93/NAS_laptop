#!/usr/bin/env bash
SCRIPT_DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$SCRIPT_DIR/pasos/lib_colores.sh"

step "PASO 6/6 — Firewall, modo servidor y script de respaldo"

# ── Firewall ──────────────────────────────────────────────────────────────────
info "Configurando firewall UFW..."
ufw --force reset  > /dev/null 2>&1
ufw default deny incoming  > /dev/null
ufw default allow outgoing > /dev/null
ufw allow 22/tcp   comment 'SSH'     > /dev/null
ufw allow 445/tcp  comment 'Samba'   > /dev/null
ufw allow 8080/tcp comment 'NAS Web' > /dev/null
ufw --force enable > /dev/null
ok "Firewall activo. Puertos: 22 (SSH), 445 (Samba), 8080 (Web)."

# ── No suspender al cerrar la tapa ───────────────────────────────────────────
info "Configurando laptop para no suspenderse (modo servidor)..."
LOGIND="/etc/systemd/logind.conf"
set_logind() {
    local key="$1" val="$2"
    if grep -q "^${key}=" "$LOGIND"; then sed -i "s/^${key}=.*/${key}=${val}/" "$LOGIND"
    elif grep -q "^#${key}=" "$LOGIND"; then sed -i "s/^#${key}=.*/${key}=${val}/" "$LOGIND"
    else echo "${key}=${val}" >> "$LOGIND"; fi
}
set_logind "HandleLidSwitch"       "ignore"
set_logind "HandleLidSwitchDocked" "ignore"
set_logind "IdleAction"            "ignore"
systemctl restart systemd-logind 2>/dev/null || true
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target > /dev/null 2>&1 || true
ok "La laptop no se suspenderá al cerrar la tapa ni por inactividad."

# ── Script de configuración del respaldo CIFS ─────────────────────────────────
info "Instalando script de configuración de respaldo..."
cat > "$NAS_HOME/configurar_respaldo.sh" << SHEOF
#!/usr/bin/env bash
# configurar_respaldo.sh — conecta el NAS con la carpeta de tu PC Windows
# USO: sudo bash $NAS_HOME/configurar_respaldo.sh

echo ""
echo "══════════════════════════════════════════════════"
echo "  CONFIGURACIÓN DE RESPALDO AUTOMÁTICO"
echo "══════════════════════════════════════════════════"
echo ""
echo "Necesito los datos de tu PC Windows para configurar"
echo "el respaldo automático de sus archivos hacia el NAS."
echo ""
echo "  (Si no sabés la IP de tu PC Windows: abrí CMD y ejecutá 'ipconfig')"
echo "  (Si no sabés cómo compartir una carpeta, revisá el archivo LEEME.md)"
echo ""
read -rp "  IP de tu PC Windows (ej: 192.168.1.50): " IP_PC
read -rp "  Nombre de la carpeta compartida en Windows (ej: Documentos): " CARPETA
read -rp "  Tu usuario de Windows: " WIN_USER
read -rsp "  Contraseña de Windows (no se muestra): " WIN_PASS
echo ""

CRED_FILE="/etc/cifs-credenciales"
printf 'username=%s\npassword=%s\n' "\$WIN_USER" "\$WIN_PASS" > "\$CRED_FILE"
chmod 600 "\$CRED_FILE"
echo "  [✓] Credenciales guardadas de forma segura en \$CRED_FILE"

mkdir -p /mnt/pc_backup

# Quitar entrada anterior si existe
sed -i '/\/mnt\/pc_backup/d' /etc/fstab

echo "//\${IP_PC}/\${CARPETA} /mnt/pc_backup cifs credentials=\${CRED_FILE},iocharset=utf8,uid=$(id -u $NAS_USER),gid=$(id -g $NAS_USER),nofail,_netdev 0 0" >> /etc/fstab
echo "  [✓] Entrada agregada a /etc/fstab"

echo "  Intentando conectar con tu PC..."
if mount -a 2>/dev/null && ls /mnt/pc_backup > /dev/null 2>&1; then
    echo "  [✓] Conexión exitosa. Archivos encontrados:"
    ls /mnt/pc_backup | head -8 | sed 's/^/      /'
    echo ""
    echo "  Iniciando respaldo automático..."
    systemctl start backup-inteligente.service
    sleep 2
    systemctl is-active --quiet backup-inteligente \
        && echo "  [✓] Respaldo automático activo." \
        || echo "  [!] Revisá con: sudo journalctl -u backup-inteligente -f"
    echo ""
    echo "  Los archivos se copiarán a: $NAS_COMPARTIDO/Backups/"
    echo "  Los logs están en: $NAS_HOME/backup.log"
else
    echo ""
    echo "  [!] No se pudo conectar. Verificá:"
    echo "      1. Que tu PC está encendida y en la misma red"
    echo "      2. Que la carpeta '\$CARPETA' está compartida en Windows"
    echo "         (click derecho → Propiedades → Compartir → Compartir...)"
    echo "      3. Que el usuario y contraseña de Windows son correctos"
    echo "      4. En Windows: Panel de control → Firewall → Permitir acceso"
    echo "         → Activar 'Compartir archivos e impresoras'"
fi
echo ""
SHEOF

chown "$NAS_USER:$NAS_USER" "$NAS_HOME/configurar_respaldo.sh"
chmod +x "$NAS_HOME/configurar_respaldo.sh"
ok "Script configurar_respaldo.sh instalado en $NAS_HOME."

# ── Cron semanal rsync a disco externo ───────────────────────────────────────
info "Configurando respaldo semanal a disco USB externo (domingos 2 AM)..."
(crontab -u "$NAS_USER" -l 2>/dev/null | grep -v "rsync.*DiscoExterno" || true
 echo "# Respaldo semanal NAS → disco USB externo"
 echo "0 2 * * 0 rsync -av --delete $NAS_COMPARTIDO/ /media/$NAS_USER/DiscoExterno/ >> $NAS_HOME/rsync.log 2>&1"
) | crontab -u "$NAS_USER" -
ok "Cron semanal configurado (requiere disco USB en /media/$NAS_USER/DiscoExterno/)."

# ── Estado final ──────────────────────────────────────────────────────────────
echo ""
echo "  Estado de servicios:"
for svc in smbd ssh nasweb backup-inteligente; do
    STATUS=$(systemctl is-active "$svc" 2>/dev/null || echo "inactivo")
    [[ "$STATUS" == "active" ]] \
        && echo -e "  ${G}[✓]${N} $svc — activo" \
        || echo -e "  ${Y}[·]${N} $svc — $STATUS"
done
echo ""
