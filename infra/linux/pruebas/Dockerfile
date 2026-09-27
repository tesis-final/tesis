# Imagen de prueba para los scripts de atlas-srv01: Ubuntu 24.04 con los mismos
# paquetes que instala 01-sistema-base.sh (menos Docker) y herramientas de red.
#   docker build -t atlas-ubuntu-test:24.04 infra/linux/pruebas
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update -qq && apt-get install -y -qq --no-install-recommends \
      iproute2 iputils-ping acl openssh-server ufw sudo chrony samba samba-common-bin \
      sssd sssd-tools realmd adcli krb5-user libpam-sss libnss-sss e2fsprogs iptables \
      dnsmasq-base isc-dhcp-relay isc-dhcp-client util-linux netcat-openbsd tcpdump \
      openssl ca-certificates curl kmod rsync \
 && rm -rf /var/lib/apt/lists/*
