# =============================================================================
# ATLAS — /etc/samba/smb.conf (Tabla 35: "Samba en Linux, accesible desde las
# máquinas del dominio"; CT-10; DEC-13: miembro del dominio con idmap_sss)
# Generado por 10-samba.sh. Probar con:  testparm -s
# =============================================================================
[global]
   workgroup = {{ATLAS_WORKGROUP}}
   realm = {{ATLAS_REALM}}
   security = ads
   # Samba y SSSD comparten la cuenta de equipo y el keytab.
   kerberos method = secrets and keytab
   dedicated keytab file = /etc/krb5.keytab

   # Identidades: las del dominio las resuelve SSSD (mismos UID/GID que en Linux).
   idmap config * : backend = tdb
   idmap config * : range = 10000-199999
   idmap config {{ATLAS_WORKGROUP}} : backend = sss
   idmap config {{ATLAS_WORKGROUP}} : range = 200000-2147483647

   # Solo la IP del servidor y solo SMB directo (445). Sin NetBIOS (139): DEC-05.
   interfaces = lo {{ATLAS_IP}}/{{ATLAS_PREFIJO}}
   bind interfaces only = yes
   smb ports = 445
   disable netbios = yes

   # Segunda capa, igual que UFW (regla 3 + DC): VLAN 10, VLAN 20 y atlas-dc01.
   hosts allow = 127.0.0.1 {{RED_ADMIN}} {{RED_DOCENTES}} {{IP_DC}}
   hosts deny = ALL

   # Protocolo moderno, firma obligatoria y cifrado cuando el cliente lo soporta.
   server min protocol = SMB2_10
   server signing = mandatory
   server smb encrypt = desired
   ntlm auth = ntlmv2-only
   restrict anonymous = 2
   map to guest = never

   # Sin impresoras (DEC-08).
   load printers = no
   printing = bsd
   printcap name = /dev/null
   disable spoolss = yes

   # Permisos de Windows guardados como ACL de Linux.
   vfs objects = acl_xattr
   map acl inherit = yes

   log file = /var/log/samba/log.%m
   max log size = 1000
   log level = 1 auth_audit:3

[administracion]
   comment = Recurso compartido de Administración (GG_Administracion)
   path = /srv/samba/administracion
   valid users = @{{AD_GRUPO_ADMINISTRACION}} @{{AD_GRUPO_SOPORTE}}
   read only = no
   browseable = yes
   access based share enum = yes
   create mask = 0660
   directory mask = 2770
   force group = {{AD_GRUPO_ADMINISTRACION}}

[docentes]
   comment = Recurso compartido de Docentes (GG_Docentes)
   path = /srv/samba/docentes
   valid users = @{{AD_GRUPO_DOCENTES}} @{{AD_GRUPO_SOPORTE}}
   read only = no
   browseable = yes
   access based share enum = yes
   create mask = 0660
   directory mask = 2770
   force group = {{AD_GRUPO_DOCENTES}}
