# ATLAS — atlas-srv01, IP fija en VLAN 40 (PDF Tabla 24, Tabla 38, Tabla 40).
# Generado por 01-sistema-base.sh. No usar DHCP en servidores (Tabla 34).
network:
  version: 2
  renderer: networkd
  ethernets:
    {{IFACE}}:
      dhcp4: false
      dhcp6: false
      addresses:
        - {{ATLAS_IP}}/{{ATLAS_PREFIJO}}
      routes:
        - to: default
          via: {{ATLAS_GATEWAY}}
      nameservers:
        addresses: [{{ATLAS_DNS}}]
        search: [{{ATLAS_DOMINIO}}]
