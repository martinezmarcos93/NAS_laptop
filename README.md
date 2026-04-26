# 💾 NAS Inteligente con Laptop Reciclada + Python

Transforma una laptop vieja (con Windows 7 u otro sistema obsoleto) en un **servidor de almacenamiento en red (NAS)** completamente funcional, controlado y automatizado con Python.

---

## ✨ Características

| Función | Tecnología |
|---|---|
| Almacenamiento en red | Samba (SMB/CIFS) |
| Respaldo automático e inteligente | Python + Watchdog |
| Panel web de gestión | Python + Flask |
| Acceso remoto sin monitor | SSH |
| Inicio automático de servicios | systemd |
| Monitoreo de recursos | psutil |

---

## 📁 Estructura del repositorio

```
nas-laptop/
├── README.md                    # Este archivo
├── INSTALL.md                   # Guía de instalación paso a paso
├── CHANGELOG.md                 # Historial de versiones
├── .gitignore
│
├── scripts/
│   ├── backup_sync.py           # Respaldo inteligente con watchdog
│   ├── monitor.py               # Monitor de disco y temperatura (alertas)
│   └── setup.sh                 # Script de instalación automatizada
│
├── panel/
│   └── nas_web.py               # Panel web Flask (subir/bajar/eliminar archivos)
│
├── services/
│   ├── backup-inteligente.service   # Servicio systemd para el backup
│   └── nasweb.service               # Servicio systemd para el panel web
│
├── config/
│   ├── smb.conf.snippet         # Bloque de configuración para Samba
│   ├── netplan-static-eth.yaml  # Plantilla IP estática por cable
│   ├── netplan-static-wifi.yaml # Plantilla IP estática por WiFi
│   └── fstab.snippet            # Línea de montaje CIFS para /etc/fstab
│
└── docs/
    ├── arquitectura.md          # Diagrama y explicación de la arquitectura
    └── faq.md                   # Preguntas frecuentes y solución de problemas
```

---

## 🚀 Inicio rápido

> **Requisitos:** Laptop con Lubuntu 22.04 LTS instalado y conexión a la red local.

```bash
# 1. Clona el repositorio en la laptop
git clone https://github.com/TU_USUARIO/NAS_laptop.git
cd nas-laptop

# 2. Ejecuta el instalador automatizado (como root)
sudo bash scripts/setup.sh

# 3. Accede al panel web desde cualquier dispositivo de tu red
#    http://192.168.1.100:8080
```

---

## 📋 Requisitos previos

- **Laptop antigua** con ≥ 1 GB RAM y disco duro funcional (ideal ≥ 100 GB)
- **Lubuntu 22.04 LTS** instalado (ver `INSTALL.md` para instrucciones)
- **PC principal** con Windows, macOS o Linux en la misma red
- **Red doméstica** (router WiFi o Ethernet)

---

## 📖 Documentación completa

- [`INSTALL.md`](INSTALL.md) — Instalación del SO, red, Samba y servicios
- [`docs/arquitectura.md`](docs/arquitectura.md) — Cómo funciona el sistema
- [`docs/faq.md`](docs/faq.md) — Problemas comunes y soluciones

---

## 🔧 Configuración rápida

Antes de ejecutar cualquier script, edita las variables en `scripts/backup_sync.py`:

```python
ORIGEN  = '/mnt/pc_backup'              # Carpeta de tu PC (montada por CIFS)
DESTINO = '/home/nasuser/Compartido/Backups'  # Destino en el NAS
```

Y en `panel/nas_web.py`:

```python
DIRECTORIO_RAIZ = '/home/nasuser/Compartido'  # Carpeta raíz del NAS
```

---

## 🛡️ Seguridad

Este proyecto está pensado para redes domésticas privadas. Para entornos compartidos se recomienda:

- Proteger Samba con usuario/contraseña (`smbpasswd`)
- Guardar credenciales CIFS en un archivo con permisos `600`
- Habilitar el firewall UFW (incluido en `setup.sh`)

---

## 🗺️ Próximos pasos (ideas)

- [ ] Notificaciones por Telegram cuando el disco supere el 90%
- [ ] Sincronización bidireccional entre equipos
- [ ] Servidor multimedia con Jellyfin
- [ ] Acceso remoto seguro con WireGuard VPN
- [ ] Cifrado de archivos sensibles con la librería `cryptography`

---

## 📄 Licencia

MIT — libre para uso personal y educativo.
