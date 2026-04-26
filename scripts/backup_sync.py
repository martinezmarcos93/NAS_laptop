#!/usr/bin/env python3
"""
backup_sync.py — Respaldo automático e inteligente hacia el NAS.

Monitoriza una carpeta de tu PC principal en tiempo real con watchdog
y copia al NAS solo los archivos nuevos o modificados.
Ejecuta también un escaneo completo al arrancar para sincronizar
el estado base antes de comenzar la vigilancia.

Uso:
    python3 backup_sync.py

Se recomienda ejecutarlo como servicio systemd (ver services/).
"""

import os
import shutil
import time
import logging
from pathlib import Path
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

# ── Configuración ────────────────────────────────────────────────────────────
# Carpeta de origen: la de tu PC, montada por CIFS (ver config/fstab.snippet)
ORIGEN = "/mnt/pc_backup"

# Carpeta de destino dentro del NAS
DESTINO = "/home/nasuser/Compartido/Backups"

# Archivo de log
LOG_FILE = "/home/nasuser/backup.log"

# Extensiones a ignorar (archivos temporales, de sistema, etc.)
IGNORAR_EXTENSIONES = {".tmp", ".temp", ".swp", ".swo", "~", ".DS_Store", ".part"}

# ── Logging ──────────────────────────────────────────────────────────────────
logging.basicConfig(
    filename=LOG_FILE,
    level=logging.INFO,
    format="%(asctime)s — %(levelname)s — %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
# También mostrar en consola (útil al ejecutar manualmente)
console = logging.StreamHandler()
console.setLevel(logging.INFO)
console.setFormatter(logging.Formatter("%(asctime)s — %(levelname)s — %(message)s"))
logging.getLogger().addHandler(console)

log = logging.getLogger(__name__)


# ── Utilidades ───────────────────────────────────────────────────────────────
def debe_ignorar(ruta: str) -> bool:
    """Devuelve True si el archivo debe omitirse en el respaldo."""
    nombre = os.path.basename(ruta)
    ext = Path(ruta).suffix.lower()
    return (
        nombre.startswith(".")
        or nombre.startswith("~")
        or ext in IGNORAR_EXTENSIONES
    )


def sincronizar_archivo(src: str) -> None:
    """Copia src al destino si es nuevo o más reciente que la copia existente."""
    if debe_ignorar(src):
        return

    rel = os.path.relpath(src, ORIGEN)
    dest = os.path.join(DESTINO, rel)

    try:
        dest_dir = os.path.dirname(dest)
        os.makedirs(dest_dir, exist_ok=True)

        copiar = (
            not os.path.exists(dest)
            or os.path.getmtime(src) > os.path.getmtime(dest)
        )

        if copiar:
            shutil.copy2(src, dest)
            log.info("Respaldado: %s", rel)
    except PermissionError:
        log.warning("Sin permisos para copiar: %s", rel)
    except OSError as e:
        log.error("Error al copiar %s → %s: %s", src, dest, e)


# ── Handler de eventos ───────────────────────────────────────────────────────
class BackupHandler(FileSystemEventHandler):
    """Reacciona a cambios en el sistema de archivos de origen."""

    def on_created(self, event):
        if not event.is_directory:
            sincronizar_archivo(event.src_path)

    def on_modified(self, event):
        if not event.is_directory:
            sincronizar_archivo(event.src_path)

    def on_moved(self, event):
        """Maneja renombramientos: copia el nuevo nombre."""
        if not event.is_directory:
            sincronizar_archivo(event.dest_path)


# ── Escaneo completo inicial ─────────────────────────────────────────────────
def escaneo_completo() -> None:
    """Recorre toda la carpeta de origen y sincroniza archivos faltantes o desactualizados."""
    log.info("Iniciando escaneo completo de: %s", ORIGEN)
    total = 0
    for root, dirs, files in os.walk(ORIGEN):
        # Excluir directorios ocultos
        dirs[:] = [d for d in dirs if not d.startswith(".")]
        for file in files:
            src = os.path.join(root, file)
            sincronizar_archivo(src)
            total += 1
    log.info("Escaneo completo finalizado. Archivos procesados: %d", total)


# ── Punto de entrada ─────────────────────────────────────────────────────────
if __name__ == "__main__":
    # Verificar que las rutas existen
    if not os.path.isdir(ORIGEN):
        log.error(
            "La carpeta de origen no existe o no está montada: %s", ORIGEN
        )
        log.error(
            "Asegúrate de haber montado la carpeta CIFS (ver INSTALL.md §8)."
        )
        raise SystemExit(1)

    os.makedirs(DESTINO, exist_ok=True)

    # Escaneo inicial para sincronizar el estado base
    escaneo_completo()

    # Monitoreo en tiempo real
    handler = BackupHandler()
    observer = Observer()
    observer.schedule(handler, path=ORIGEN, recursive=True)
    observer.start()
    log.info("Monitor de cambios en tiempo real iniciado. Observando: %s", ORIGEN)

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        log.info("Deteniendo el monitor...")
        observer.stop()

    observer.join()
    log.info("Servicio de respaldo detenido.")
