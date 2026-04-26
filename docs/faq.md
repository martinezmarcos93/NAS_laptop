# ❓ Preguntas Frecuentes y Solución de Problemas

---

## Instalación del sistema operativo

**¿Cuál ISO de Lubuntu descargo, 32 o 64 bits?**

Si tu laptop tiene menos de 4 GB de RAM o es anterior a 2010, usa la imagen **i386 (32 bits)**. Si tiene 4 GB o más y es posterior a 2010, usa **amd64 (64 bits)**. Ante la duda, i386 funciona en ambos casos (a costo de algo de rendimiento en hardware de 64 bits).

**La laptop no arranca desde el USB.**

- Verifica que el USB se creó correctamente con Rufus o balenaEtcher.
- Asegúrate de elegir el esquema de partición correcto: **MBR** para BIOS, **GPT** para UEFI.
- Entra al BIOS/UEFI (F2, Del o F10 al arrancar) y verifica que el arranque desde USB esté habilitado y sea el primero en la lista.
- Si el equipo usa Secure Boot, desactívalo en el BIOS antes de instalar Linux.

---

## Red y SSH

**No puedo conectarme por SSH (`ssh nasuser@192.168.1.100`).**

1. Verifica que el servicio SSH está corriendo en la laptop:
   ```bash
   sudo systemctl status ssh
   ```
2. Comprueba que la IP de la laptop es la correcta:
   ```bash
   ip a
   ```
3. Desde tu PC, haz `ping 192.168.1.100` para verificar conectividad básica.
4. Verifica que el firewall permite el puerto 22:
   ```bash
   sudo ufw status
   ```

**La IP de la laptop cambia después de reiniciar.**

Significa que Netplan no se aplicó correctamente. Revisa la sintaxis del archivo YAML (usa espacios, no tabulaciones) y vuelve a ejecutar `sudo netplan apply`. Puedes verificar errores con `sudo netplan try`.

---

## Samba

**No veo la carpeta compartida desde Windows.**

1. Verifica que Samba está corriendo:
   ```bash
   sudo systemctl status smbd
   ```
2. Prueba la ruta directamente en el Explorador: `\\192.168.1.100\AlmacenNAS`
3. Desde Windows, verifica con `ping 192.168.1.100` que hay conectividad.
4. Asegúrate de que el firewall permite el puerto 445:
   ```bash
   sudo ufw allow 445/tcp
   ```
5. En Windows 11, puede ser necesario habilitar SMB1 o la detección de redes. Ve a Panel de control → Programas → Activar o desactivar características de Windows → Compatibilidad con el protocolo para compartir archivos SMBDirect.

**No puedo escribir archivos en la carpeta compartida.**

Verifica los permisos de la carpeta:
```bash
ls -la /home/nasuser/Compartido
```
Si no muestra `rwxrwxrwx`, aplica:
```bash
sudo chmod 777 /home/nasuser/Compartido
```

---

## Backup automático

**El servicio de backup no arranca (`systemctl status backup-inteligente` muestra error).**

1. Verifica que el script existe en la ruta correcta:
   ```bash
   ls -l /home/nasuser/backup_sync.py
   ```
2. Prueba ejecutarlo manualmente para ver el error:
   ```bash
   sudo -u nasuser python3 /home/nasuser/backup_sync.py
   ```
3. El error más común es que la carpeta CIFS no está montada. Verifica:
   ```bash
   ls /mnt/pc_backup
   ```

**El script de backup dice "carpeta de origen no encontrada".**

La carpeta `/mnt/pc_backup` no está montada. Ejecuta:
```bash
sudo mount -a
```
Si falla, verifica la línea en `/etc/fstab` y que el PC origen esté encendido y compartiendo la carpeta.

**Los archivos se copian pero con retraso.**

Watchdog usa notificaciones del sistema de archivos. Sobre montajes CIFS (red), las notificaciones pueden tardar o no funcionar correctamente. En ese caso, el escaneo completo al arrancar garantiza la sincronización inicial. Para sincronización más frecuente, puedes programar reinicios del servicio con `cron`.

---

## Panel web

**No puedo acceder al panel en `http://192.168.1.100:8080`.**

1. Verifica que el servicio Flask está corriendo:
   ```bash
   sudo systemctl status nasweb
   ```
2. Prueba ejecutarlo manualmente:
   ```bash
   sudo -u nasuser python3 /home/nasuser/nas_web.py
   ```
3. Verifica que el firewall permite el puerto 8080:
   ```bash
   sudo ufw allow 8080/tcp
   ```

**El panel muestra "500 Internal Server Error" al subir archivos.**

El archivo puede superar el límite de 500 MB configurado. Edita `nas_web.py` y aumenta el valor de `MAX_UPLOAD_MB`. También verifica que hay espacio libre en el disco.

---

## Monitor de alertas

**No recibo correos de alerta.**

1. Verifica que usas una **contraseña de aplicación** de Gmail, no tu contraseña real.
2. Asegúrate de que la verificación en dos pasos está habilitada en tu cuenta Google (requisito para contraseñas de aplicación).
3. Prueba el envío manualmente:
   ```bash
   python3 -c "
   import smtplib
   s = smtplib.SMTP_SSL('smtp.gmail.com', 465)
   s.login('tu@gmail.com', 'xxxx xxxx xxxx xxxx')
   print('OK')
   s.quit()
   "
   ```

**`psutil.sensors_temperatures()` devuelve vacío o error.**

No todos los modelos de laptop exponen sensores de temperatura al sistema operativo. Instala `lm-sensors` y ejecútalo:
```bash
sudo apt install lm-sensors -y
sudo sensors-detect
sensors
```
Si aun así no hay sensores disponibles, el monitor seguirá funcionando pero omitirá las alertas de temperatura.

---

## General

**¿Puedo acceder al NAS desde fuera de mi red local (desde internet)?**

No directamente con esta configuración. Para acceso remoto seguro, considera instalar **WireGuard VPN** en la laptop. Esto crea un túnel cifrado hacia tu red doméstica sin exponer puertos al exterior.

**¿Qué pasa si se corta la luz?**

La batería de la laptop actúa como un SAI (Sistema de Alimentación Ininterrumpida). Cuando vuelve la corriente, la laptop arranca y todos los servicios se reinician automáticamente gracias a systemd (configurados con `WantedBy=multi-user.target`).

**¿El NAS funciona si apago el monitor/pantalla de la laptop?**

Sí. Lubuntu puede configurarse para no suspenderse al cerrar la tapa o apagar la pantalla. Ve a Preferencias del sistema → Administrador de energía → deshabilita "Suspender al cerrar la tapa".

También puedes hacerlo desde la terminal:
```bash
sudo nano /etc/systemd/logind.conf
```
Cambia o agrega:
```
HandleLidSwitch=ignore
HandleLidSwitchDocked=ignore
```
Luego:
```bash
sudo systemctl restart systemd-logind
```
