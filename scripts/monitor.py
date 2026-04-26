#!/usr/bin/env python3
"""
monitor.py — Monitor de recursos del NAS con alertas por correo.

Verifica periódicamente:
  - Uso del disco (alerta si supera UMBRAL_DISCO %)
  - Temperatura de la CPU (alerta si supera UMBRAL_TEMP °C)
  - Memoria RAM disponible (aviso informativo)

Envía notificaciones por correo electrónico usando una cuenta Gmail
con contraseña de aplicación (ver instrucciones abajo).

Uso:
    python3 monitor.py

Se recomienda ejecutarlo como servicio systemd (ver services/).

── Configurar Gmail ────────────────────────────────────────────────────────────
1. Habilita la verificación en dos pasos en tu cuenta Google.
2. Ve a: Cuenta Google → Seguridad → Contraseñas de aplicación.
3. Genera una contraseña para "Correo / Otro dispositivo".
4. Úsala en EMAIL_PASSWORD (nunca tu contraseña real de Gmail).
"""

import os
import time
import smtplib
import logging
import psutil
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime

# ── Configuración ────────────────────────────────────────────────────────────
DIRECTORIO_NAS = "/home/nasuser/Compartido"

UMBRAL_DISCO = 90       # % de uso del disco para activar alerta
UMBRAL_TEMP  = 70       # °C de temperatura de CPU para activar alerta
INTERVALO    = 300      # segundos entre cada verificación (300 = 5 minutos)

# Correo electrónico (usa contraseña de aplicación de Gmail, no tu clave real)
EMAIL_ORIGEN   = "tu_correo@gmail.com"       # Cuenta que envía la alerta
EMAIL_DESTINO  = "tu_correo@gmail.com"       # Cuenta que recibe la alerta
EMAIL_PASSWORD = "xxxx xxxx xxxx xxxx"       # Contraseña de aplicación Gmail

LOG_FILE = "/home/nasuser/monitor.log"

# ── Logging ──────────────────────────────────────────────────────────────────
logging.basicConfig(
    filename=LOG_FILE,
    level=logging.INFO,
    format="%(asctime)s — %(levelname)s — %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
console = logging.StreamHandler()
console.setFormatter(logging.Formatter("%(asctime)s — %(levelname)s — %(message)s"))
logging.getLogger().addHandler(console)
log = logging.getLogger(__name__)


# ── Envío de correo ──────────────────────────────────────────────────────────
def enviar_alerta(asunto: str, cuerpo: str) -> None:
    """Envía un correo de alerta usando SMTP de Gmail."""
    try:
        msg = MIMEMultipart()
        msg["From"]    = EMAIL_ORIGEN
        msg["To"]      = EMAIL_DESTINO
        msg["Subject"] = f"[NAS Alerta] {asunto}"
        msg.attach(MIMEText(cuerpo, "plain", "utf-8"))

        with smtplib.SMTP_SSL("smtp.gmail.com", 465) as servidor:
            servidor.login(EMAIL_ORIGEN, EMAIL_PASSWORD)
            servidor.sendmail(EMAIL_ORIGEN, EMAIL_DESTINO, msg.as_string())

        log.info("Alerta enviada: %s", asunto)
    except smtplib.SMTPAuthenticationError:
        log.error("Error de autenticación SMTP. Verifica EMAIL_PASSWORD.")
    except Exception as e:
        log.error("No se pudo enviar el correo: %s", e)


# ── Obtener métricas ─────────────────────────────────────────────────────────
def obtener_uso_disco() -> dict:
    """Retorna el uso del disco del directorio NAS."""
    uso = psutil.disk_usage(DIRECTORIO_NAS)
    return {
        "total_gb": round(uso.total / 1e9, 1),
        "usado_gb": round(uso.used  / 1e9, 1),
        "libre_gb": round(uso.free  / 1e9, 1),
        "porcentaje": uso.percent,
    }


def obtener_temperatura() -> float | None:
    """Retorna la temperatura máxima de la CPU en °C, o None si no está disponible."""
    try:
        temps = psutil.sensors_temperatures()
        if not temps:
            return None
        maxima = 0.0
        for sensor_list in temps.values():
            for entrada in sensor_list:
                if entrada.current > maxima:
                    maxima = entrada.current
        return round(maxima, 1) if maxima > 0 else None
    except AttributeError:
        # psutil.sensors_temperatures() no disponible en todos los SO
        return None


def obtener_ram() -> dict:
    """Retorna el uso de la memoria RAM."""
    mem = psutil.virtual_memory()
    return {
        "total_mb": round(mem.total / 1e6),
        "disponible_mb": round(mem.available / 1e6),
        "porcentaje": mem.percent,
    }


# ── Ciclo de verificación ────────────────────────────────────────────────────
def verificar() -> None:
    """Ejecuta una ronda de verificación y envía alertas si corresponde."""
    disco = obtener_uso_disco()
    temp  = obtener_temperatura()
    ram   = obtener_ram()
    hora  = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    log.info(
        "Disco: %s GB / %s GB (%s%%) | RAM: %s MB libres (%s%%) | Temp CPU: %s°C",
        disco["usado_gb"], disco["total_gb"], disco["porcentaje"],
        ram["disponible_mb"], ram["porcentaje"],
        temp if temp is not None else "N/D",
    )

    # Alerta de disco lleno
    if disco["porcentaje"] >= UMBRAL_DISCO:
        asunto = f"Disco al {disco['porcentaje']}% — Solo {disco['libre_gb']} GB libres"
        cuerpo = (
            f"El disco del NAS ha superado el umbral de alerta.\n\n"
            f"Fecha y hora: {hora}\n"
            f"Uso del disco: {disco['usado_gb']} GB de {disco['total_gb']} GB ({disco['porcentaje']}%)\n"
            f"Espacio libre: {disco['libre_gb']} GB\n\n"
            f"Considera liberar espacio o conectar almacenamiento adicional."
        )
        enviar_alerta(asunto, cuerpo)

    # Alerta de temperatura
    if temp is not None and temp >= UMBRAL_TEMP:
        asunto = f"Temperatura CPU elevada: {temp}°C"
        cuerpo = (
            f"La temperatura de la CPU del NAS ha superado el umbral de seguridad.\n\n"
            f"Fecha y hora: {hora}\n"
            f"Temperatura máxima detectada: {temp}°C\n"
            f"Umbral configurado: {UMBRAL_TEMP}°C\n\n"
            f"Verifica la ventilación del equipo."
        )
        enviar_alerta(asunto, cuerpo)


# ── Punto de entrada ─────────────────────────────────────────────────────────
if __name__ == "__main__":
    if not os.path.isdir(DIRECTORIO_NAS):
        log.error("Directorio NAS no encontrado: %s", DIRECTORIO_NAS)
        raise SystemExit(1)

    log.info(
        "Monitor iniciado. Verificando cada %d segundos. "
        "Umbral disco: %d%% | Umbral temp: %d°C",
        INTERVALO, UMBRAL_DISCO, UMBRAL_TEMP,
    )

    while True:
        try:
            verificar()
        except Exception as e:
            log.error("Error inesperado en la verificación: %s", e)
        time.sleep(INTERVALO)
