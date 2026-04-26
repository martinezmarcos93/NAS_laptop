#!/usr/bin/env python3
"""
nas_web.py — Panel web de administración del NAS.

Interfaz web ligera (Flask) para gestionar los archivos del NAS
desde cualquier navegador de la red local.

Funciones:
  - Ver espacio total, usado y libre con barra visual
  - Subir archivos (límite configurable, 500 MB por defecto)
  - Descargar archivos
  - Eliminar archivos con confirmación
  - Navegar subcarpetas

Acceso: http://IP_DEL_NAS:8080

Uso:
    python3 nas_web.py

Se recomienda ejecutarlo como servicio systemd (ver services/nasweb.service).
"""

import os
import psutil
from pathlib import Path
from flask import (
    Flask,
    render_template_string,
    request,
    redirect,
    url_for,
    send_from_directory,
    flash,
    abort,
)

# ── Configuración ────────────────────────────────────────────────────────────
DIRECTORIO_RAIZ    = "/home/nasuser/Compartido"
MAX_UPLOAD_MB      = 500
PUERTO             = 8080

app = Flask(__name__)
app.secret_key = os.urandom(24)          # Para mensajes flash
app.config["MAX_CONTENT_LENGTH"] = MAX_UPLOAD_MB * 1024 * 1024


# ── Utilidades ───────────────────────────────────────────────────────────────
def ruta_segura(subcarpeta: str) -> str:
    """Resuelve la ruta real y verifica que esté dentro de DIRECTORIO_RAIZ."""
    base = Path(DIRECTORIO_RAIZ).resolve()
    destino = (base / subcarpeta).resolve()
    if not str(destino).startswith(str(base)):
        abort(403)  # Intento de path traversal
    return str(destino)


def obtener_espacio() -> dict:
    uso = psutil.disk_usage(DIRECTORIO_RAIZ)
    return {
        "total":      round(uso.total / 1e9, 1),
        "usado":      round(uso.used  / 1e9, 1),
        "libre":      round(uso.free  / 1e9, 1),
        "porcentaje": uso.percent,
    }


def listar_directorio(carpeta: str) -> tuple[list, list]:
    """Devuelve (subcarpetas, archivos) en la carpeta indicada."""
    carpetas, archivos = [], []
    try:
        for entrada in sorted(os.scandir(carpeta), key=lambda e: e.name.lower()):
            if entrada.name.startswith("."):
                continue
            if entrada.is_dir():
                carpetas.append({"nombre": entrada.name})
            elif entrada.is_file():
                archivos.append({
                    "nombre":    entrada.name,
                    "tamano_mb": round(entrada.stat().st_size / 1e6, 2),
                })
    except PermissionError:
        flash("Sin permisos para acceder a esta carpeta.", "error")
    return carpetas, archivos


# ── Plantilla HTML ────────────────────────────────────────────────────────────
HTML = """<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>💾 NAS Inteligente</title>
  <style>
    :root {
      --primary: #1a5276;
      --accent:  #2980b9;
      --light:   #d6eaf8;
      --danger:  #e74c3c;
      --success: #27ae60;
      --bg:      #f4f6f8;
      --card:    #ffffff;
      --text:    #2c3e50;
      --muted:   #7f8c8d;
      --border:  #d5dbdb;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: Arial, sans-serif; background: var(--bg); color: var(--text); font-size: 15px; }
    header {
      background: var(--primary); color: #fff;
      padding: 16px 32px; display: flex; align-items: center; gap: 12px;
      box-shadow: 0 2px 6px rgba(0,0,0,.2);
    }
    header h1 { font-size: 1.4rem; font-weight: 700; }
    header span { font-size: 0.9rem; opacity: .75; }
    .container { max-width: 960px; margin: 0 auto; padding: 24px 16px; }

    /* Tarjeta */
    .card {
      background: var(--card); border-radius: 8px;
      box-shadow: 0 1px 4px rgba(0,0,0,.1); padding: 20px; margin-bottom: 20px;
    }
    .card h2 { font-size: 1rem; color: var(--primary); margin-bottom: 14px;
               border-bottom: 2px solid var(--light); padding-bottom: 6px; }

    /* Disco */
    .disco-stats { display: flex; gap: 24px; margin-bottom: 12px; font-size: 0.9rem; }
    .disco-stats span { color: var(--muted); }
    .disco-stats strong { color: var(--text); }
    .barra { background: var(--border); border-radius: 20px; height: 18px; overflow: hidden; }
    .barra-llena {
      background: linear-gradient(90deg, var(--accent), var(--primary));
      height: 100%; border-radius: 20px;
      display: flex; align-items: center; justify-content: center;
      color: #fff; font-size: 0.75rem; font-weight: bold;
      transition: width .4s ease;
    }
    .barra-llena.warn  { background: linear-gradient(90deg, #f39c12, #e67e22); }
    .barra-llena.alert { background: linear-gradient(90deg, #e74c3c, #c0392b); }

    /* Migas de pan */
    .breadcrumb { font-size: 0.85rem; margin-bottom: 12px; color: var(--muted); }
    .breadcrumb a { color: var(--accent); text-decoration: none; }
    .breadcrumb a:hover { text-decoration: underline; }

    /* Upload */
    .upload-form { display: flex; gap: 10px; flex-wrap: wrap; align-items: center; }
    .upload-form input[type=file] { flex: 1; min-width: 200px; padding: 6px;
      border: 1px solid var(--border); border-radius: 6px; background: var(--bg); }
    .btn { padding: 8px 18px; border: none; border-radius: 6px; cursor: pointer;
           font-size: 0.9rem; font-weight: bold; transition: opacity .15s; }
    .btn:hover { opacity: .85; }
    .btn-primary  { background: var(--accent);  color: #fff; }
    .btn-success  { background: var(--success); color: #fff; }
    .btn-danger   { background: var(--danger);  color: #fff; padding: 4px 10px; font-size: 0.8rem; }
    .btn-download { background: var(--primary); color: #fff; padding: 4px 10px; font-size: 0.8rem; }
    .btn-folder   { background: var(--light);   color: var(--primary); padding: 4px 10px; font-size: 0.8rem; }

    /* Tabla */
    table { width: 100%; border-collapse: collapse; font-size: 0.9rem; }
    thead th { background: var(--primary); color: #fff; padding: 10px 12px; text-align: left; }
    tbody tr:nth-child(even) { background: var(--bg); }
    tbody tr:hover { background: var(--light); }
    td { padding: 9px 12px; border-bottom: 1px solid var(--border); vertical-align: middle; }
    td.acciones { display: flex; gap: 6px; }
    .icon-folder { margin-right: 5px; }

    /* Mensajes flash */
    .flash { padding: 10px 16px; border-radius: 6px; margin-bottom: 14px; font-size: 0.9rem; }
    .flash.ok    { background: #eafaf1; border-left: 4px solid var(--success); color: #1e8449; }
    .flash.error { background: #fdecea; border-left: 4px solid var(--danger);  color: #922b21; }

    /* Sin archivos */
    .vacio { text-align: center; padding: 32px; color: var(--muted); font-style: italic; }

    footer { text-align: center; font-size: 0.8rem; color: var(--muted); padding: 20px 0; }
  </style>
</head>
<body>
<header>
  <div>💾</div>
  <div>
    <h1>NAS Inteligente</h1>
    <span>Panel de administración — Laptop reciclada</span>
  </div>
</header>

<div class="container">

  {% with msgs = get_flashed_messages(with_categories=true) %}
    {% for cat, msg in msgs %}
      <div class="flash {{ cat }}">{{ msg }}</div>
    {% endfor %}
  {% endwith %}

  <!-- Espacio en disco -->
  <div class="card">
    <h2>📊 Almacenamiento</h2>
    <div class="disco-stats">
      <span>Total: <strong>{{ espacio.total }} GB</strong></span>
      <span>Usado: <strong>{{ espacio.usado }} GB</strong></span>
      <span>Libre: <strong>{{ espacio.libre }} GB</strong></span>
      <span>Uso: <strong>{{ espacio.porcentaje }}%</strong></span>
    </div>
    <div class="barra">
      <div class="barra-llena
        {% if espacio.porcentaje >= 90 %}alert
        {% elif espacio.porcentaje >= 75 %}warn{% endif %}"
        style="width: {{ espacio.porcentaje }}%">
        {{ espacio.porcentaje }}%
      </div>
    </div>
  </div>

  <!-- Subir archivo -->
  <div class="card">
    <h2>⬆️ Subir archivo</h2>
    <form class="upload-form" action="{{ url_for('subir', sub=sub_actual) }}" method="post" enctype="multipart/form-data">
      <input type="file" name="archivo" required>
      <button class="btn btn-primary" type="submit">Subir</button>
    </form>
    <p style="font-size:0.8rem;color:var(--muted);margin-top:8px;">Tamaño máximo: {{ max_mb }} MB</p>
  </div>

  <!-- Explorador de archivos -->
  <div class="card">
    <h2>📂 Archivos</h2>

    <!-- Breadcrumb -->
    <div class="breadcrumb">
      <a href="{{ url_for('index') }}">Inicio</a>
      {% for parte in breadcrumb %}
        &nbsp;/&nbsp;<a href="{{ url_for('index', sub=parte.ruta) }}">{{ parte.nombre }}</a>
      {% endfor %}
    </div>

    {% if carpetas or archivos %}
    <table>
      <thead>
        <tr>
          <th>Nombre</th>
          <th>Tamaño</th>
          <th>Acciones</th>
        </tr>
      </thead>
      <tbody>
        <!-- Carpetas -->
        {% for c in carpetas %}
        <tr>
          <td><span class="icon-folder">📁</span>{{ c.nombre }}</td>
          <td>—</td>
          <td class="acciones">
            <a href="{{ url_for('index', sub=(sub_actual + '/' + c.nombre).lstrip('/')) }}">
              <button class="btn btn-folder">Abrir</button>
            </a>
          </td>
        </tr>
        {% endfor %}
        <!-- Archivos -->
        {% for a in archivos %}
        <tr>
          <td>📄 {{ a.nombre }}</td>
          <td>{{ a.tamano_mb }} MB</td>
          <td class="acciones">
            <a href="{{ url_for('descargar', sub=sub_actual, nombre=a.nombre) }}">
              <button class="btn btn-download">⬇ Descargar</button>
            </a>
            <a href="{{ url_for('eliminar', sub=sub_actual, nombre=a.nombre) }}"
               onclick="return confirm('¿Eliminar {{ a.nombre }}? Esta acción no se puede deshacer.')">
              <button class="btn btn-danger">🗑 Eliminar</button>
            </a>
          </td>
        </tr>
        {% endfor %}
      </tbody>
    </table>
    {% else %}
      <p class="vacio">Esta carpeta está vacía. ¡Sube tu primer archivo!</p>
    {% endif %}
  </div>

</div>

<footer>NAS Inteligente v2.0 — Laptop reciclada con Python &amp; Flask</footer>
</body>
</html>
"""


# ── Rutas Flask ───────────────────────────────────────────────────────────────
@app.route("/")
@app.route("/browse")
def index():
    sub = request.args.get("sub", "").strip("/")
    carpeta_actual = ruta_segura(sub)
    espacio = obtener_espacio()
    carpetas, archivos = listar_directorio(carpeta_actual)

    # Construir migas de pan
    partes = [p for p in sub.split("/") if p]
    breadcrumb = [
        {"nombre": p, "ruta": "/".join(partes[: i + 1])}
        for i, p in enumerate(partes)
    ]

    return render_template_string(
        HTML,
        espacio=espacio,
        carpetas=carpetas,
        archivos=archivos,
        sub_actual=sub,
        breadcrumb=breadcrumb,
        max_mb=MAX_UPLOAD_MB,
    )


@app.route("/subir", methods=["POST"])
def subir():
    sub = request.args.get("sub", "").strip("/")
    carpeta_destino = ruta_segura(sub)
    archivo = request.files.get("archivo")

    if not archivo or not archivo.filename:
        flash("No se seleccionó ningún archivo.", "error")
        return redirect(url_for("index", sub=sub))

    nombre = Path(archivo.filename).name           # Evita rutas peligrosas
    destino = os.path.join(carpeta_destino, nombre)

    try:
        archivo.save(destino)
        flash(f"Archivo '{nombre}' subido correctamente.", "ok")
    except OSError as e:
        flash(f"Error al guardar el archivo: {e}", "error")

    return redirect(url_for("index", sub=sub))


@app.route("/descargar")
def descargar():
    sub    = request.args.get("sub", "").strip("/")
    nombre = request.args.get("nombre", "")
    carpeta = ruta_segura(sub)
    return send_from_directory(carpeta, nombre, as_attachment=True)


@app.route("/eliminar")
def eliminar():
    sub    = request.args.get("sub", "").strip("/")
    nombre = request.args.get("nombre", "")
    ruta   = ruta_segura(os.path.join(sub, nombre))

    if os.path.isfile(ruta):
        try:
            os.remove(ruta)
            flash(f"Archivo '{nombre}' eliminado.", "ok")
        except OSError as e:
            flash(f"Error al eliminar el archivo: {e}", "error")
    else:
        flash("Archivo no encontrado.", "error")

    return redirect(url_for("index", sub=sub))


# ── Punto de entrada ──────────────────────────────────────────────────────────
if __name__ == "__main__":
    if not os.path.isdir(DIRECTORIO_RAIZ):
        print(f"[ERROR] Directorio raíz no encontrado: {DIRECTORIO_RAIZ}")
        raise SystemExit(1)

    print(f"[NAS Web] Iniciando en http://0.0.0.0:{PUERTO}")
    print(f"[NAS Web] Directorio raíz: {DIRECTORIO_RAIZ}")
    app.run(host="0.0.0.0", port=PUERTO, debug=False)
