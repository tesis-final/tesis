# =============================================================================
# ATLAS — /etc/sssd/sssd.conf (Tabla 35: autenticación centralizada con SSSD/Kerberos)
# Generado por 09-dominio.sh. Modo 600 root:root (SSSD no arranca con otro modo).
# =============================================================================
[sssd]
domains = {{ATLAS_DOMINIO}}
config_file_version = 2
services = nss, pam

[domain/{{ATLAS_DOMINIO}}]
id_provider = ad
auth_provider = ad
chpass_provider = ad
ad_domain = {{ATLAS_DOMINIO}}
krb5_realm = {{ATLAS_REALM}}
ad_server = {{ATLAS_DC_FQDN}}
realmd_tags = manages-system joined-with-samba
# UID/GID calculados a partir del SID: iguales en SSSD y en Samba (idmap_sss, DEC-13).
ldap_id_mapping = True
# Nombres cortos y en minúsculas: "gg_soporteti", como los usa sshd (DEC-07).
use_fully_qualified_names = False
case_sensitive = False
fallback_homedir = /home/%u
default_shell = /bin/bash
cache_credentials = True
# Solo Soporte TI puede iniciar sesión en el servidor (Tabla 36). Docentes y
# estudiantes existen en el dominio pero no entran a Linux (§28.2).
access_provider = simple
simple_allow_groups = {{AD_GRUPO_SOPORTE}}
# Las GPO de Windows no se aplican a este servidor Linux.
ad_gpo_access_control = disabled
dyndns_update = True
dyndns_refresh_interval = 43200
