# 📦 Guía de Instalación — NAS Inteligente con Laptop Reciclada

Esta guía cubre todo el proceso desde cero: instalación del sistema operativo, configuración de red, Samba y los servicios Python.

---

## Índice

1. [Instalar Lubuntu 22.04 LTS](#1-instalar-lubuntu-2204-lts)
2. [Configurar red con IP estática](#2-configurar-red-con-ip-estática)
3. [Habilitar SSH](#3-habilitar-ssh)
4. [Instalar y configurar Samba](#4-instalar-y-configurar-samba)
5. [Instalar Python y dependencias](#5-instalar-python-y-dependencias)
6. [Clonar el repositorio y configurar](#6-clonar-el-repositorio-y-configurar)
7. [Activar los servicios systemd](#7-activar-los-servicios-systemd)
8. [Montar la carpeta de tu PC (CIFS)](#8-montar-la-carpeta-de-tu-pc-cifs)
9. [Verificación final](#9-verificación-final)

---

## 1. Instalar Lubuntu 22.04 LTS

### 1.1 Descargar la ISO

Visita https://lubuntu.me/downloads/ y descarga la versión **22.04 LTS (Jammy Jellyfish)**:

- Laptop con **< 4 GB RAM o anterior a 2010** → imagen **i386 (32 bits)**
- Laptop con **≥ 4 GB RAM y posterior a 2010** → imagen **amd64 (64 bits)**

> Ante la duda, usa la de 32 bits.

### 1.2 Crear el USB de instalación

Con **Rufus** (Windows) o **balenaEtcher** (multiplataforma):

1. Conecta el pendrive USB (≥ 4 GB — se borrará todo su contenido).
2. Selecciona la ISO descargada.
3. Esquema de partición: **MBR** para BIOS tradicional, **GPT** si usa UEFI.
4. Inicia el proceso y espera.

### 1.3 Instalar en la laptop

1. Apaga la laptop, inserta el USB y enciéndela.
2. Presiona la tecla del menú de arranque: **F12**, **F9**, **Esc** o **F2** (depende del fabricante).
3. Elige arrancar desde el USB.
4. En el menú de Lubuntu: **Start Lubuntu** → doble clic en el instalador.
5. Configuración recomendada:
   - **Idioma:** Español
   - **Tipo de instalación:** "Borrar disco y usar todo el espacio"
   - **Usuario:** `nasuser`
   - **Contraseña:** una segura (¡anótala!)
6. Espera entre 10 y 30 minutos. Retira el USB al finalizar y reinicia.

---

## 2. Configurar red con IP estática

Una IP fija garantiza que la dirección del NAS no cambie entre reinicios.

### 2.1 Ver el nombre de tu interfaz de red

```bash
ip a
```

Busca `eth0` (cable Ethernet) o `wlan0` (WiFi).

### 2.2 Editar la configuración de Netplan

```bash
sudo nano /etc/netplan/01-network-manager-all.yaml
```

**Para Ethernet**, copia el contenido de `config/netplan-static-eth.yaml` y ajusta:
- `eth0` → tu interfaz real
- `192.168.1.100` → IP deseada para el NAS
- `192.168.1.1` → IP de tu router

**Para WiFi**, usa `config/netplan-static-wifi.yaml` y añade también el nombre y contraseña de tu red.

### 2.3 Aplicar cambios

```bash
sudo netplan apply
```

Verifica con `ip a` que la IP se asignó correctamente.

---

## 3. Habilitar SSH

El acceso SSH permite controlar la laptop desde tu PC sin necesidad de monitor ni teclado.

```bash
sudo apt update
sudo apt install openssh-server -y
sudo systemctl enable ssh
sudo systemctl start ssh
```

**Probar desde tu PC principal:**

```bash
ssh nasuser@192.168.1.100
```

Acepta la huella digital e ingresa la contraseña. Si ves el prompt, ¡funciona!

---

## 4. Instalar y configurar Samba

Samba comparte la carpeta del NAS con equipos Windows, macOS y Linux.

### 4.1 Instalar

```bash
sudo apt install samba -y
```

### 4.2 Crear la carpeta compartida

```bash
mkdir -p /home/nasuser/Compartido/Backups
sudo chmod 777 /home/nasuser/Compartido
```

### 4.3 Configurar

```bash
sudo nano /etc/samba/smb.conf
```

Ve al final del archivo y pega el contenido de `config/smb.conf.snippet`.

```bash
sudo systemctl restart smbd
sudo systemctl enable smbd
sudo systemctl status smbd   # Debe mostrar: active (running)
```

### 4.4 Conectar desde tu PC

| Sistema | Dirección |
|---|---|
| Windows (Explorador) | `\\192.168.1.100\AlmacenNAS` |
| macOS (Finder → Ir → Conectar) | `smb://192.168.1.100/AlmacenNAS` |
| Linux (administrador de archivos) | `smb://192.168.1.100/AlmacenNAS` |

Para mapear como unidad permanente en Windows: clic derecho en "Este equipo" → "Conectar a unidad de red..." → letra `Z:` → ruta `\\192.168.1.100\AlmacenNAS`.

---

## 5. Instalar Python y dependencias

```bash
sudo apt install python3 python3-pip git -y
pip3 install watchdog flask psutil
```

---

## 6. Clonar el repositorio y configurar

```bash
cd /home/nasuser
git clone https://github.com/TU_USUARIO/nas-laptop.git
cd nas-laptop
```

### 6.1 Ajustar rutas en los scripts

Edita `scripts/backup_sync.py` y cambia:

```python
ORIGEN  = '/mnt/pc_backup'              # Carpeta de tu PC (montada por CIFS)
DESTINO = '/home/nasuser/Compartido/Backups'
```

Edita `panel/nas_web.py` y cambia si es necesario:

```python
DIRECTORIO_RAIZ = '/home/nasuser/Compartido'
```

### 6.2 Ajustar los archivos de servicio

Edita `services/backup-inteligente.service` y `services/nasweb.service` si tu usuario no es `nasuser`.

---

## 7. Activar los servicios systemd

```bash
# Copiar los archivos de servicio al directorio de systemd
sudo cp services/backup-inteligente.service /etc/systemd/system/
sudo cp services/nasweb.service /etc/systemd/system/

# Recargar systemd y activar ambos servicios
sudo systemctl daemon-reload

sudo systemctl enable backup-inteligente.service
sudo systemctl start backup-inteligente.service

sudo systemctl enable nasweb.service
sudo systemctl start nasweb.service

# Verificar estado
sudo systemctl status backup-inteligente.service
sudo systemctl status nasweb.service
```

---

## 8. Montar la carpeta de tu PC (CIFS)

Para que el script de respaldo acceda a archivos de tu PC principal:

### 8.1 Instalar cifs-utils

```bash
sudo apt install cifs-utils -y
sudo mkdir -p /mnt/pc_backup
```

### 8.2 Configurar el montaje automático

Crea un archivo de credenciales (más seguro que escribirlas en fstab):

```bash
sudo nano /etc/cifs-credenciales
```

Contenido:

```
username=TU_USUARIO_WINDOWS
password=TU_CONTRASEÑA
```

Asegura el archivo:

```bash
sudo chmod 600 /etc/cifs-credenciales
```

### 8.3 Agregar a /etc/fstab

```bash
sudo nano /etc/fstab
```

Pega el contenido de `config/fstab.snippet` y ajusta la IP, nombre de carpeta compartida y ruta de credenciales.

```bash
sudo mount -a
ls /mnt/pc_backup   # Deberías ver los archivos de tu PC
```

---

## 9. Verificación final

```bash
# Estado de todos los servicios
sudo systemctl status smbd backup-inteligente nasweb

# Ver logs del backup
tail -f /home/nasuser/backup.log

# Ver logs del panel web
sudo journalctl -u nasweb -f
```

Accede al panel desde tu navegador:

```
http://192.168.1.100:8080
```

Si todo muestra `active (running)` y el panel carga correctamente, **¡el NAS está en marcha!** 🎉

---

## Firewall (recomendado)

```bash
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 445/tcp   # Samba
sudo ufw allow 8080/tcp  # Panel web
sudo ufw enable
sudo ufw status
```
