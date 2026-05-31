# sshplus-teu

# Instalación 
```
wget -O install.sh https://raw.githubusercontent.com/rogellevi/sshplus-teu/main/install.sh && bash install.sh
```

# menú tiene 6 opciones:
```
[1] Instalar SSHPLUS
[2] Instalar Panel Web HTTP
[3] Instalar SSL Let's Encrypt
[4] Instalación Completa (SSHPLUS + Panel + SSL)
[5] Actualizar Panel
[6] Renovar Certificado SSL
[0] Salir
```

La opción 4 hace todo de un solo clic — ideal para VPS limpio. 🚀


#########################################$$

# Instalación 2
```
wget -O install.sh https://raw.githubusercontent.com/rogellevi/sshplus-teu/main/install2.sh && bash install2.sh
```

# menú tiene 6 opciones:
```
[1] Instalar SSHPLUS
[2] Instalar Panel Web HTTP
[3] Instalar SSL Let's Encrypt
[4] Instalación Completa (SSHPLUS + Panel + SSL)
[5] Actualizar Panel
[6] Renovar Certificado SSL
[7] Usar certificado existente (acme.sh)
[0] Salir
```

# Lo que hace:

```
1.- Lista todos los certificados acme.sh disponibles
2.- Preguntas el dominio (ej: v2ray.cloudgt.xyz)
3.- Detecta automáticamente si es _ecc o normal
4.- Preguntas el puerto HTTPS
5.- Configura Apache con ese certificado
6.- Activa renovación automática con cron
```
