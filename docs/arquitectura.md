# 🏗️ Arquitectura del NAS Inteligente

Este documento describe cómo interactúan los componentes del sistema.

---

## Diagrama general

```
┌─────────────────────────────────────────────────────────────────┐
│                         RED LOCAL (LAN)                         │
│                      192.168.1.0/24                             │
│                                                                  │
│   ┌────────────────┐       SMB/CIFS        ┌─────────────────┐  │
│   │   PC principal │ ◄──────────────────── │   LAPTOP (NAS)  │  │
│   │  192.168.1.50  │       :445            │  192.168.1.100  │  │
│   │                │                       │                 │  │
│   │  Carpeta       │ ─────────────────────►│  /mnt/pc_backup │  │
│   │  compartida    │       CIFS mount      │        │        │  │
│   │  (Windows)     │                       │        ▼        │  │
│   └────────────────┘                       │  backup_sync.py │  │
│                                            │  (watchdog)     │  │
│   ┌────────────────┐                       │        │        │  │
│   │  Navegador web │ ◄─────────────────────│        ▼        │  │
│   │  (cualquier    │       HTTP :8080      │  /Compartido/   │  │
│   │   dispositivo) │                       │  Backups/       │  │
│   └────────────────┘       nas_web.py      │                 │  │
│                             (Flask)        │  nas_web.py     │  │
│                                            │  (Flask :8080)  │  │
│                                            │                 │  │
│                                            │  smbd (Samba)   │  │
│                                            │  sshd (SSH :22) │  │
│                                            └─────────────────┘  │
│                                                    │             │
│                                             Router/Switch        │
│                                            192.168.1.1          │
└─────────────────────────────────────────────────────────────────┘
```

---

## Componentes y su función

### Sistema operativo: Lubuntu 22.04 LTS

Distribución Ubuntu con entorno gráfico LXQt, optimizada para hardware antiguo. Consume alrededor de 300–500 MB de RAM en reposo. Compatible con arquitecturas i386 (32 bits) y amd64 (64 bits).

### Samba (SMB/CIFS)

Protocolo estándar de compartición de archivos en redes locales. Permite que la carpeta `/home/nasuser/Compartido` aparezca como una unidad de red en Windows, macOS y Linux sin necesidad de software adicional en el cliente.

Puerto utilizado: `445/tcp`

### SSH (OpenSSH Server)

Acceso remoto seguro a la terminal de la laptop. Permite administrar el NAS desde tu PC principal sin necesidad de conectar monitor ni teclado a la laptop.

Puerto utilizado: `22/tcp`

### backup_sync.py + watchdog

Script Python que:

1. Al arrancar, realiza un **escaneo completo** de la carpeta origen para sincronizar el estado base.
2. Luego activa un **observador en tiempo real** (watchdog) que detecta archivos creados, modificados o renombrados.
3. Por cada evento, copia el archivo al NAS **solo si es nuevo o más reciente** que la copia existente.
4. Registra todas las operaciones en `/home/nasuser/backup.log`.

La carpeta origen (`/mnt/pc_backup`) es la carpeta de tu PC montada mediante CIFS. El destino es `/home/nasuser/Compartido/Backups`.

### nas_web.py (Flask)

Panel web ligero que ofrece:

- Visualización del espacio en disco con barra de uso
- Navegación por carpetas del NAS
- Subida de archivos (límite configurable, 500 MB por defecto)
- Descarga de archivos
- Eliminación de archivos con confirmación

Accesible en `http://192.168.1.100:8080` desde cualquier dispositivo de la red.

### monitor.py

Proceso independiente que cada 5 minutos verifica:

- **Uso del disco:** si supera el 90%, envía una alerta por correo.
- **Temperatura CPU:** si supera los 70 °C, envía una alerta por correo.

Usa `psutil` para las métricas y `smtplib` con Gmail SMTP para las notificaciones.

### systemd

Gestor de servicios de Linux. Garantiza que `backup_sync.py`, `nas_web.py` y (opcionalmente) `monitor.py` se inicien automáticamente con el sistema y se reinicien si fallan.

---

## Flujo de un respaldo típico

```
[PC principal]                           [Laptop NAS]
     │                                        │
     │  El usuario guarda un archivo en       │
     │  C:\Documentos\proyecto.docx           │
     │                                        │
     │  watchdog detecta el evento            │
     │  "on_modified"                         │
     │                                        │
     │ ──── CIFS (red local) ────────────►   │
     │      /mnt/pc_backup/proyecto.docx      │
     │                                        │
     │                              backup_sync.py compara
     │                              fechas de modificación
     │                                        │
     │                              Si src > dest → shutil.copy2()
     │                                        │
     │                              /Compartido/Backups/proyecto.docx
     │                              Registra en backup.log
```

---

## Puertos y servicios activos

| Puerto | Protocolo | Servicio | Descripción |
|--------|-----------|---------|-------------|
| 22 | TCP | SSH | Administración remota |
| 445 | TCP | Samba | Acceso a archivos en red |
| 8080 | TCP | Flask | Panel web de administración |

---

## Consumo estimado de recursos

| Recurso | En reposo | Con carga (backup activo) |
|---------|-----------|--------------------------|
| RAM | ~350 MB | ~450 MB |
| CPU | < 5% | 10–30% |
| Red | mínimo | según tamaño de archivos |
| Consumo eléctrico | ~12 W | ~20 W |

*Valores aproximados para una laptop con CPU de doble núcleo y 2 GB de RAM.*
