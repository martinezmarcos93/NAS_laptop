# 🚀 NAS Inteligente — Instalador Automático

---

## PARTE 1 — Lo que hacés en la LAPTOP VIEJA

### Paso 1 · Copiar esta carpeta a la laptop

**Opción A — Por USB (más fácil):**
1. Copiá la carpeta `nas-installer` a un pendrive
2. Conectá el pendrive a la laptop
3. Abrí el administrador de archivos de Ubuntu, buscá el pendrive
4. Copiá la carpeta `nas-installer` al Escritorio de la laptop

**Opción B — Por red (si ya tenés SSH funcionando):**
Desde tu PC Windows, abrí PowerShell y escribí:
```
scp -r nas-installer TU_USUARIO@IP_LAPTOP:/home/TU_USUARIO/
```

---

### Paso 2 · Ejecutar el instalador

Abrí una terminal en la laptop (Ctrl + Alt + T) y escribí:

```bash
cd ~/Desktop/nas-installer        # o donde lo hayas copiado
sudo bash INSTALAR_NAS.sh
```

Ingresá tu contraseña de Ubuntu cuando te la pida.
El script hace todo solo. Al terminar te muestra la IP de tu NAS.

> ⏱ Tiempo estimado: entre 5 y 15 minutos según tu conexión a internet.

---

## PARTE 2 — Lo que hacés en tu PC WINDOWS

> Hacé esto **después** de que el instalador termine en la laptop.

---

### Paso 3 · Averiguar la IP de tu NAS

El instalador te la muestra al terminar. También podés verla así:
- En la laptop, abrí una terminal y escribí: `ip a`
- Buscá una línea que diga `inet 192.168.X.X` (no la que dice `127.0.0.1`)
- Esa es la IP. Anótala. Ejemplo: `192.168.1.100`

---

### Paso 4 · Acceder a los archivos del NAS desde Windows

1. Abrí el **Explorador de archivos** (la carpeta amarilla en la barra de tareas)
2. Hacé click en la **barra de direcciones** (donde dice "Este equipo" o una ruta)
3. Borrá lo que hay y escribí exactamente esto (con tu IP real):
   ```
   \\192.168.1.100\AlmacenNAS
   ```
4. Presioná **Enter**
5. Si te pide usuario y contraseña, escribí `nas1234` en ambos campos

Deberías ver las carpetas del NAS: Backups, Documentos, Fotos, Videos.

---

### Paso 5 · Mapear el NAS como unidad permanente (recomendado)

Así el NAS aparece como "Disco Z:" cada vez que arrancás Windows, igual que un disco externo.

1. Abrí el **Explorador de archivos**
2. Hacé click derecho en **"Este equipo"** (panel izquierdo)
3. Elegí **"Conectar a unidad de red..."**

   ![menú contextual](https://i.imgur.com/placeholder.png)

4. En la ventana que aparece:
   - **Unidad:** elegí la letra `Z:` (o cualquier letra libre)
   - **Carpeta:** escribí `\\192.168.1.100\AlmacenNAS` (con tu IP real)
   - **Tildá** la opción "Conectar de nuevo al iniciar sesión"
   - **No** tildes "Conectar con otras credenciales" si el acceso es libre

5. Hacé click en **Finalizar**

6. Ahora en "Este equipo" vas a ver una nueva unidad llamada **AlmacenNAS (Z:)**
   Podés copiar y pegar archivos ahí igual que en cualquier carpeta.

---

### Paso 6 · Abrir el panel web

El panel web te permite ver, subir, descargar y eliminar archivos desde el navegador,
sin necesidad de mapear nada.

1. Abrí **Chrome, Firefox o Edge**
2. En la barra de direcciones escribí:
   ```
   http://192.168.1.100:8080
   ```
   (reemplazá con tu IP real)
3. Deberías ver el panel del NAS con la barra de espacio en disco y los archivos

---

### Paso 7 · Configurar el respaldo automático de tu PC (opcional)

Esto hace que la laptop copie automáticamente una carpeta de tu PC hacia el NAS.

#### En tu PC Windows primero:

1. Buscá la carpeta que querés respaldar (por ejemplo: `Documentos`)
2. Hacé **click derecho** sobre ella → **Propiedades**
3. Hacé click en la pestaña **Compartir**
4. Hacé click en **Compartir...**
5. En el campo del medio, hacé click en la lista desplegable y elegí tu usuario
6. Hacé click en **Agregar**
7. Asegurate de que en "Nivel de permiso" diga **Lectura** (alcanza para respaldar)
8. Hacé click en **Compartir** y luego en **Listo**
9. Anotá el **nombre de la carpeta compartida** que aparece
   (generalmente es el mismo nombre de la carpeta, ej: `Documentos`)

Después necesitás averiguar la **IP de tu PC Windows**:
1. Abrí el menú Inicio
2. Escribí `cmd` y presioná Enter
3. En la ventana negra escribí: `ipconfig`
4. Buscá la línea que dice **"Dirección IPv4"** debajo de tu adaptador de red
5. Eso es la IP de tu PC. Ejemplo: `192.168.1.50`

#### En la laptop (con una terminal):

```bash
sudo bash /home/TU_USUARIO/configurar_respaldo.sh
```

El script te pregunta:
- La IP de tu PC Windows (la que anotaste en el paso anterior)
- El nombre de la carpeta compartida
- Tu usuario y contraseña de Windows

Y configura todo solo. Los archivos se van a copiar automáticamente
cada vez que los modifiques.

---

### Paso 8 · Acceder a la laptop de forma remota (opcional)

Podés controlar la laptop desde tu PC sin necesidad de monitor ni teclado.

**En Windows 10/11** (PowerShell o CMD):
```
ssh TU_USUARIO@192.168.1.100
```
La primera vez te pregunta si confiás en el equipo → escribí `yes` y Enter.
Después pedirá la contraseña de Ubuntu de la laptop.

Si usás Windows 7 o preferís una interfaz gráfica, instalá **PuTTY** (gratuito):
- Descargalo de: https://www.putty.org
- En "Host Name" escribí la IP de la laptop
- Hacé click en "Open"

---

## Solución de problemas comunes

**No aparece la carpeta en `\\192.168.1.100\AlmacenNAS`**
- Verificá que ambos equipos están en la misma red WiFi o cable
- Probá hacer `ping 192.168.1.100` desde CMD de Windows
  Si no responde, la IP puede haber cambiado → revisá con `ip a` en la laptop

**Windows pide usuario y contraseña**
- Usuario: tu usuario de Ubuntu (o `nas1234`)
- Contraseña: `nas1234`

**El panel web no carga**
- Verificá que la laptop esté encendida
- Probá desde la laptop: `sudo systemctl status nasweb`

**El respaldo no funciona**
- En la laptop: `tail -20 /home/TU_USUARIO/backup.log`
- Verificá que la carpeta de Windows esté compartida correctamente (Paso 7)

---

## Referencia rápida

| Qué | Cómo |
|-----|------|
| Ver archivos del NAS | `\\IP_NAS\AlmacenNAS` en el Explorador |
| Panel web | `http://IP_NAS:8080` en el navegador |
| Ver IP del NAS | En la laptop: `ip a` |
| Ver IP de tu PC | En Windows CMD: `ipconfig` |
| Estado de servicios | En la laptop: `sudo systemctl status nasweb smbd` |
| Logs del respaldo | En la laptop: `tail -f ~/backup.log` |
| Configurar respaldo | En la laptop: `sudo bash ~/configurar_respaldo.sh` |
