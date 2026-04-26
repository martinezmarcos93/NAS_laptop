#!/usr/bin/env bash
SCRIPT_DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$SCRIPT_DIR/pasos/lib_colores.sh"

step "PASO 5/6 — Instalando scripts Python y servicios del sistema"

PYTHON=$(command -v python3 || command -v python)
[[ -z "$PYTHON" ]] && err "Python3 no encontrado."
ok "Python: $PYTHON — Usuario: $NAS_USER — Home: $NAS_HOME"

# ── backup_sync.py ────────────────────────────────────────────────────────────
info "Instalando script de respaldo automático..."
cat > "$NAS_HOME/backup_sync.py" << PYEOF
#!/usr/bin/env python3
"""backup_sync.py — Respaldo automático inteligente hacia el NAS."""

import os, shutil, time, logging
from pathlib import Path
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

ORIGEN   = "/mnt/pc_backup"
DESTINO  = "$NAS_COMPARTIDO/Backups"
LOG_FILE = "$NAS_HOME/backup.log"
IGNORAR  = {".tmp", ".temp", ".swp", ".part", ".DS_Store"}

logging.basicConfig(filename=LOG_FILE, level=logging.INFO,
    format="%(asctime)s — %(levelname)s — %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S")
console = logging.StreamHandler()
console.setFormatter(logging.Formatter("%(asctime)s — %(levelname)s — %(message)s"))
logging.getLogger().addHandler(console)
log = logging.getLogger(__name__)

def debe_ignorar(ruta):
    n = os.path.basename(ruta)
    return n.startswith(".") or Path(ruta).suffix.lower() in IGNORAR

def sincronizar(src):
    if debe_ignorar(src): return
    rel  = os.path.relpath(src, ORIGEN)
    dest = os.path.join(DESTINO, rel)
    try:
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        if not os.path.exists(dest) or os.path.getmtime(src) > os.path.getmtime(dest):
            shutil.copy2(src, dest)
            log.info("Respaldado: %s", rel)
    except (PermissionError, OSError) as e:
        log.error("Error copiando %s: %s", rel, e)

class BackupHandler(FileSystemEventHandler):
    def on_created(self, ev):
        if not ev.is_directory: sincronizar(ev.src_path)
    def on_modified(self, ev):
        if not ev.is_directory: sincronizar(ev.src_path)
    def on_moved(self, ev):
        if not ev.is_directory: sincronizar(ev.dest_path)

def escaneo_completo():
    log.info("Escaneo inicial: %s", ORIGEN)
    for root, dirs, files in os.walk(ORIGEN):
        dirs[:] = [d for d in dirs if not d.startswith(".")]
        for f in files: sincronizar(os.path.join(root, f))
    log.info("Escaneo inicial completado.")

if __name__ == "__main__":
    if not os.path.isdir(ORIGEN):
        log.error("Carpeta origen no encontrada: %s", ORIGEN)
        log.error("Ejecutá primero: sudo bash $NAS_HOME/configurar_respaldo.sh")
        raise SystemExit(1)
    os.makedirs(DESTINO, exist_ok=True)
    escaneo_completo()
    observer = Observer()
    observer.schedule(BackupHandler(), path=ORIGEN, recursive=True)
    observer.start()
    log.info("Monitor en tiempo real iniciado.")
    try:
        while True: time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
    observer.join()
PYEOF

# ── nas_web.py ────────────────────────────────────────────────────────────────
info "Instalando panel web Flask..."
cat > "$NAS_HOME/nas_web.py" << PYEOF
#!/usr/bin/env python3
"""nas_web.py — Panel web del NAS. Acceso: http://IP:8080"""

import os, psutil
from pathlib import Path
from flask import (Flask, render_template_string, request,
                   redirect, url_for, send_from_directory, flash, abort)

DIRECTORIO_RAIZ = "$NAS_COMPARTIDO"
MAX_UPLOAD_MB   = 500
PUERTO          = 8080

app = Flask(__name__)
app.secret_key = os.urandom(24)
app.config["MAX_CONTENT_LENGTH"] = MAX_UPLOAD_MB * 1024 * 1024

def ruta_segura(sub):
    base = Path(DIRECTORIO_RAIZ).resolve()
    dest = (base / sub).resolve()
    if not str(dest).startswith(str(base)): abort(403)
    return str(dest)

def espacio():
    u = psutil.disk_usage(DIRECTORIO_RAIZ)
    return {"total":round(u.total/1e9,1),"usado":round(u.used/1e9,1),
            "libre":round(u.free/1e9,1),"pct":u.percent}

def listar(carpeta):
    dirs, files = [], []
    try:
        for e in sorted(os.scandir(carpeta), key=lambda x: x.name.lower()):
            if e.name.startswith("."): continue
            if e.is_dir(): dirs.append({"nombre":e.name})
            elif e.is_file(): files.append({"nombre":e.name,"mb":round(e.stat().st_size/1e6,2)})
    except PermissionError: flash("Sin permisos.", "error")
    return dirs, files

HTML = """<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
  <title>💾 NAS</title>
  <style>
    :root{--p:#1a5276;--a:#2980b9;--l:#d6eaf8;--d:#e74c3c;--s:#27ae60;--bg:#f4f6f8;--bdr:#d5dbdb}
    *{box-sizing:border-box;margin:0;padding:0}
    body{font-family:Arial,sans-serif;background:var(--bg);color:#2c3e50;font-size:15px}
    header{background:var(--p);color:#fff;padding:14px 28px;display:flex;align-items:center;gap:10px;box-shadow:0 2px 6px rgba(0,0,0,.2)}
    header h1{font-size:1.3rem} header small{opacity:.7;font-size:.85rem}
    .wrap{max-width:900px;margin:0 auto;padding:20px 14px}
    .card{background:#fff;border-radius:8px;box-shadow:0 1px 4px rgba(0,0,0,.1);padding:18px;margin-bottom:18px}
    .card h2{font-size:.95rem;color:var(--p);margin-bottom:12px;border-bottom:2px solid var(--l);padding-bottom:5px}
    .stats{display:flex;gap:20px;margin-bottom:10px;font-size:.88rem;flex-wrap:wrap}
    .stats span{color:#7f8c8d} .stats strong{color:#2c3e50}
    .bar{background:var(--bdr);border-radius:20px;height:16px;overflow:hidden}
    .fill{height:100%;border-radius:20px;background:linear-gradient(90deg,var(--a),var(--p));
          display:flex;align-items:center;justify-content:center;color:#fff;font-size:.7rem;font-weight:bold}
    .fill.warn{background:linear-gradient(90deg,#f39c12,#e67e22)}
    .fill.alrt{background:linear-gradient(90deg,#e74c3c,#c0392b)}
    .bc{font-size:.82rem;margin-bottom:10px;color:#7f8c8d}
    .bc a{color:var(--a);text-decoration:none} .bc a:hover{text-decoration:underline}
    .upform{display:flex;gap:8px;flex-wrap:wrap;align-items:center}
    .upform input[type=file]{flex:1;min-width:180px;padding:5px;border:1px solid var(--bdr);border-radius:5px;background:var(--bg)}
    .btn{padding:7px 16px;border:none;border-radius:5px;cursor:pointer;font-size:.85rem;font-weight:bold;transition:opacity .15s}
    .btn:hover{opacity:.82}
    .bp{background:var(--a);color:#fff} .bd{background:var(--d);color:#fff;padding:4px 9px;font-size:.78rem}
    .bl{background:var(--p);color:#fff;padding:4px 9px;font-size:.78rem}
    .bf{background:var(--l);color:var(--p);padding:4px 9px;font-size:.78rem}
    table{width:100%;border-collapse:collapse;font-size:.88rem}
    thead th{background:var(--p);color:#fff;padding:9px 10px;text-align:left}
    tbody tr:nth-child(even){background:var(--bg)} tbody tr:hover{background:var(--l)}
    td{padding:8px 10px;border-bottom:1px solid var(--bdr);vertical-align:middle}
    .ac{display:flex;gap:5px}
    .fl{padding:9px 14px;border-radius:5px;margin-bottom:12px;font-size:.88rem}
    .fl.ok{background:#eafaf1;border-left:4px solid var(--s);color:#1e8449}
    .fl.error{background:#fdecea;border-left:4px solid var(--d);color:#922b21}
    .empty{text-align:center;padding:28px;color:#7f8c8d;font-style:italic}
    footer{text-align:center;font-size:.78rem;color:#aaa;padding:16px 0}
  </style>
</head>
<body>
<header>
  <span style="font-size:1.6rem">💾</span>
  <div><h1>NAS Inteligente</h1><small>Panel de administración</small></div>
</header>
<div class="wrap">
  {% with msgs = get_flashed_messages(with_categories=true) %}
    {% for cat,msg in msgs %}<div class="fl {{cat}}">{{msg}}</div>{% endfor %}
  {% endwith %}
  <div class="card">
    <h2>📊 Almacenamiento</h2>
    <div class="stats">
      <span>Total: <strong>{{e.total}} GB</strong></span>
      <span>Usado: <strong>{{e.usado}} GB</strong></span>
      <span>Libre: <strong>{{e.libre}} GB</strong></span>
      <span>Uso: <strong>{{e.pct}}%</strong></span>
    </div>
    <div class="bar">
      <div class="fill {% if e.pct>=90 %}alrt{% elif e.pct>=75 %}warn{% endif %}"
           style="width:{{e.pct}}%">{{e.pct}}%</div>
    </div>
  </div>
  <div class="card">
    <h2>⬆️ Subir archivo</h2>
    <form class="upform" action="{{url_for('subir',sub=sub)}}" method="post" enctype="multipart/form-data">
      <input type="file" name="archivo" required>
      <button class="btn bp" type="submit">Subir</button>
    </form>
    <p style="font-size:.78rem;color:#aaa;margin-top:7px">Máximo {{max_mb}} MB por archivo</p>
  </div>
  <div class="card">
    <h2>📂 Archivos</h2>
    <div class="bc">
      <a href="{{url_for('index')}}">Inicio</a>
      {% for p in breadcrumb %} / <a href="{{url_for('index',sub=p.ruta)}}">{{p.nombre}}</a>{% endfor %}
    </div>
    {% if carpetas or archivos %}
    <table>
      <thead><tr><th>Nombre</th><th>Tamaño</th><th>Acciones</th></tr></thead>
      <tbody>
        {% for c in carpetas %}
        <tr><td>📁 {{c.nombre}}</td><td>—</td>
          <td class="ac"><a href="{{url_for('index',sub=(sub+'/'+c.nombre).lstrip('/'))}}">
            <button class="btn bf">Abrir</button></a></td></tr>
        {% endfor %}
        {% for a in archivos %}
        <tr><td>📄 {{a.nombre}}</td><td>{{a.mb}} MB</td>
          <td class="ac">
            <a href="{{url_for('descargar',sub=sub,nombre=a.nombre)}}"><button class="btn bl">⬇ Bajar</button></a>
            <a href="{{url_for('eliminar',sub=sub,nombre=a.nombre)}}"
               onclick="return confirm('¿Eliminar {{a.nombre}}?')"><button class="btn bd">🗑 Eliminar</button></a>
          </td></tr>
        {% endfor %}
      </tbody>
    </table>
    {% else %}<p class="empty">Carpeta vacía. ¡Subí tu primer archivo!</p>{% endif %}
  </div>
</div>
<footer>NAS Inteligente v2.0 — Flask + Python | Usuario: $NAS_USER</footer>
</body></html>"""

@app.route("/")
@app.route("/browse")
def index():
    sub = request.args.get("sub","").strip("/")
    e = espacio(); dirs, files = listar(ruta_segura(sub))
    partes = [p for p in sub.split("/") if p]
    bc = [{"nombre":p,"ruta":"/".join(partes[:i+1])} for i,p in enumerate(partes)]
    return render_template_string(HTML, e=e, carpetas=dirs, archivos=files,
                                  sub=sub, breadcrumb=bc, max_mb=MAX_UPLOAD_MB)

@app.route("/subir", methods=["POST"])
def subir():
    sub = request.args.get("sub","").strip("/")
    f = request.files.get("archivo")
    if not f or not f.filename: flash("No se seleccionó archivo.", "error"); return redirect(url_for("index",sub=sub))
    nombre = Path(f.filename).name
    try: f.save(os.path.join(ruta_segura(sub), nombre)); flash(f"'{nombre}' subido.", "ok")
    except OSError as e: flash(f"Error: {e}", "error")
    return redirect(url_for("index", sub=sub))

@app.route("/descargar")
def descargar():
    return send_from_directory(ruta_segura(request.args.get("sub","").strip("/")),
                               request.args.get("nombre",""), as_attachment=True)

@app.route("/eliminar")
def eliminar():
    sub = request.args.get("sub","").strip("/")
    nombre = request.args.get("nombre","")
    ruta = ruta_segura(os.path.join(sub, nombre))
    if os.path.isfile(ruta):
        try: os.remove(ruta); flash(f"'{nombre}' eliminado.", "ok")
        except OSError as e: flash(f"Error: {e}", "error")
    else: flash("Archivo no encontrado.", "error")
    return redirect(url_for("index", sub=sub))

if __name__ == "__main__":
    if not os.path.isdir(DIRECTORIO_RAIZ):
        print(f"[ERROR] No existe: {DIRECTORIO_RAIZ}"); raise SystemExit(1)
    print(f"[NAS Web] → http://0.0.0.0:{PUERTO}")
    app.run(host="0.0.0.0", port=PUERTO, debug=False)
PYEOF

chown "$NAS_USER:$NAS_USER" "$NAS_HOME/backup_sync.py" "$NAS_HOME/nas_web.py"
chmod +x "$NAS_HOME/backup_sync.py" "$NAS_HOME/nas_web.py"
ok "Scripts Python instalados en $NAS_HOME."

# ── Servicios systemd ─────────────────────────────────────────────────────────
info "Instalando servicios systemd..."
PYTHON_PATH=$(command -v python3)
UID_USER=$(id -u "$NAS_USER")

cat > /etc/systemd/system/backup-inteligente.service << SVCEOF
[Unit]
Description=NAS — Respaldo automático inteligente
After=network.target smbd.service
Wants=network.target

[Service]
Type=simple
User=$NAS_USER
Group=$NAS_USER
WorkingDirectory=$NAS_HOME
ExecStartPre=/bin/sleep 20
ExecStart=$PYTHON_PATH $NAS_HOME/backup_sync.py
Restart=on-failure
RestartSec=30
Nice=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=nas-backup

[Install]
WantedBy=multi-user.target
SVCEOF

cat > /etc/systemd/system/nasweb.service << SVCEOF
[Unit]
Description=NAS — Panel web Flask
After=network.target
Wants=network.target

[Service]
Type=simple
User=$NAS_USER
Group=$NAS_USER
WorkingDirectory=$NAS_HOME
ExecStart=$PYTHON_PATH $NAS_HOME/nas_web.py
Restart=on-failure
RestartSec=10
Environment=PYTHONUNBUFFERED=1
StandardOutput=journal
StandardError=journal
SyslogIdentifier=nas-web

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
systemctl enable backup-inteligente.service --quiet
ok "Servicio backup-inteligente registrado (arrancará con el sistema)."
systemctl enable nasweb.service --quiet
systemctl start nasweb.service
sleep 2
systemctl is-active --quiet nasweb \
    && ok "Panel web activo en http://$(cat /tmp/nas_ip 2>/dev/null || hostname -I | awk '{print $1}'):8080" \
    || warn "Panel web no inició. Revisá: sudo journalctl -u nasweb -f"
