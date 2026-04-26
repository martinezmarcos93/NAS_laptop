# Changelog

Todos los cambios notables de este proyecto se documentan aquí.
El formato sigue [Keep a Changelog](https://keepachangelog.com/es/1.0.0/).

---

## [2.0.0] — 2026-04-25

### Añadido
- Script de respaldo con logging a archivo (`backup.log`)
- Monitor de disco y temperatura con alertas por correo (`scripts/monitor.py`)
- Script de instalación automatizada (`scripts/setup.sh`)
- Plantillas de configuración de Netplan para Ethernet y WiFi
- Archivo de credenciales CIFS separado (más seguro que fstab en texto plano)
- Documentación de arquitectura y FAQ
- Soporte de límite de tamaño de archivo en el panel web (500 MB por defecto)

### Mejorado
- Script `backup_sync.py` refactorizado con mejor manejo de errores
- Panel web con barra de uso de disco y tabla de archivos mejorada
- `README.md` con tabla de características y guía de inicio rápido
- Servicios systemd con política de reinicio automático

### Corregido
- Permisos en la carpeta compartida al crearla con `setup.sh`
- Ruta del intérprete Python en los archivos `.service`

---

## [1.0.0] — 2026-04-01

### Añadido
- Versión inicial del proyecto
- Configuración básica de Samba
- Script de respaldo con watchdog
- Panel web básico con Flask
- Servicios systemd para backup y panel web
