#!/usr/bin/env bash
# =============================================================================
# ATLAS · Fase 6 — Verificación de atlas-srv01
# Comprueba cada requisito del PDF (§28, Tabla 35/36) y de las decisiones, y
# escribe PASS / FAIL por ítem. La salida sirve como evidencia (E-LNX-nnn).
#
# Uso: sudo ./verificar.sh [secciones...]      (sin argumentos: todas)
#      Secciones: usuarios permisos atributos ssh firewall docker atlas hora dominio samba registros sudo
#      sudo ./verificar.sh > /tmp/E-LNX-001-verificacion.txt
# =============================================================================
# "A && ok || mal" es intencional: ok() y mal() nunca fallan.
# shellcheck disable=SC2015,SC2016
set -uo pipefail
BASE="$(cd "$(dirname "$0")" && pwd)"
[ -f "$BASE/parametros.conf" ] || BASE=/usr/local/lib/atlas
# shellcheck source=parametros.conf
source "${ATLAS_PARAMETROS:-$BASE/parametros.conf}"
R="$ATLAS_ROOT"
[ "$(id -u)" -eq 0 ] || { echo "Correr con sudo."; exit 1; }

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; }
mal()  { FAIL=$((FAIL+1)); printf '  FAIL  %s%s\n' "$1" "${2:+  →  $2}"; }
chk()  { local d="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else mal "$d"; fi; }
tit()  { printf '\n[%s] %s\n' "$1" "$2"; }

# --- usuarios: Tabla 25 y Tabla 26 -------------------------------------------
sec_usuarios() {
  tit usuarios "Grupos y usuarios (Tabla 25, Tabla 26)"
  local g gid
  for par in atlas-admin:5001 atlas-web:5002 atlas-db:5003 atlas-backup:5004 atlas-audit:5005; do
    g="${par%%:*}"; gid="${par##*:}"
    [ "$(getent group "$g" | cut -d: -f3)" = "$gid" ] && ok "grupo $g GID $gid" || mal "grupo $g GID $gid"
  done
  local u uid grp sh
  while read -r u uid grp sh; do
    local l; l="$(getent passwd "$u")"
    if [ "$(echo "$l" | cut -d: -f3)" = "$uid" ] && [ "$(id -gn "$u" 2>/dev/null)" = "$grp" ] && [ "$(echo "$l" | cut -d: -f7)" = "$sh" ]; then
      ok "usuario $u UID $uid grupo $grp shell $sh"
    else mal "usuario $u UID $uid grupo $grp shell $sh" "$l"; fi
  done <<'T'
atlasadmin 5001 atlas-admin /bin/bash
atlasweb 5002 atlas-web /usr/sbin/nologin
atlasdb 5003 atlas-db /usr/sbin/nologin
atlasbkp 5004 atlas-backup /usr/sbin/nologin
T
  for u in atlasweb atlasdb atlasbkp; do
    [ "$(passwd -S "$u" | awk '{print $2}')" = L ] && ok "$u sin contraseña utilizable" || mal "$u sin contraseña utilizable"
  done
}

# --- permisos: §28.3 + Tabla 27, celda por celda ------------------------------
efectivo() {  # rol ruta → "rwx" efectivo, medido con access() como ese rol
  local rol="$1" ruta="$2" cmd
  case "$rol" in
    admin)  cmd=(setpriv --reuid=atlasadmin --regid=atlas-admin --init-groups) ;;
    web)    cmd=(setpriv --reuid=atlasweb   --regid=atlas-web   --init-groups) ;;
    db)     cmd=(setpriv --reuid=atlasdb    --regid=atlas-db    --init-groups) ;;
    backup) cmd=(setpriv --reuid=atlasbkp   --regid=atlas-backup --init-groups) ;;
    # atlas-audit no tiene usuario local (DEC-18): se prueba con "nobody" + solo ese grupo.
    audit)  cmd=(setpriv --reuid=65534 --regid=5005 --clear-groups) ;;
  esac
  "${cmd[@]}" bash -c 'p="$1"; printf "%s%s%s" "$([ -r "$p" ] && echo r || echo -)" "$([ -w "$p" ] && echo w || echo -)" "$([ -x "$p" ] && echo x || echo -)"' _ "$ruta"
}
modo_base() {  # ruta → modo octal de las entradas base de la ACL (user::, group::, other::)
  getfacl -cp "$1" 2>/dev/null | awk -F: '
    function oct(p) { return (substr(p,1,1)=="r")*4 + (substr(p,2,1)=="w")*2 + (substr(p,3,1)=="x") }
    $1=="user"  && $2=="" { u=oct($3) }
    $1=="group" && $2=="" { g=oct($3) }
    $1=="other"           { o=oct($3) }
    END { printf "%d%d%d", u, g, o }'
}
sec_permisos() {
  tit permisos "Dueños y modos (§28.3)"
  # Con ACL, "ls -l" y "stat" muestran la MÁSCARA en el lugar del grupo. El modo
  # real de §28.3 se lee de las entradas user::, group:: y other:: de getfacl.
  local ruta esperado real
  while read -r ruta esperado; do
    real="$(stat -c '%U:%G' "$R/$ruta" 2>/dev/null) $(modo_base "$R/$ruta")"
    [ "$real" = "$esperado" ] && ok "$R/$ruta $esperado" || mal "$R/$ruta $esperado" "tiene: ${real:-no existe}"
  done <<'T'
. atlasadmin:atlas-admin 750
web atlasweb:atlas-web 750
web/public atlasweb:atlas-web 755
web/app atlasweb:atlas-web 750
datos atlasdb:atlas-db 770
logs atlasadmin:atlas-admin 770
scripts atlasadmin:atlas-admin 750
config atlasadmin:atlas-admin 750
backups atlasbkp:atlas-backup 700
T
  tit permisos "Permisos efectivos (Tabla 27). 'r--' en directorios = r-x (DEC-06)"
  printf '  %-22s %-7s %-7s %-7s %-7s %-7s\n' Recurso admin web db backup audit
  local rec cols i rol esp med linea todo_ok
  local roles=(admin web db backup audit)
  while read -r rec cols; do
    linea="$(printf '  %-22s' "$R/$rec/")"; todo_ok=si
    read -r -a esps <<< "$cols"
    for i in 0 1 2 3 4; do
      rol="${roles[$i]}"; esp="${esps[$i]}"
      [ "$esp" = "r--" ] && esp="r-x"
      [ "$esp" = "—" ] && esp="---"
      med="$(efectivo "$rol" "$R/$rec")"
      if [ "$med" = "$esp" ]; then linea+="$(printf ' %-7s' "$med")"; else linea+="$(printf ' %-7s' "$med!")"; todo_ok=no; fi
    done
    echo "$linea"
    [ "$todo_ok" = si ] && ok "Tabla 27 fila $rec" || mal "Tabla 27 fila $rec" "las celdas con ! no coinciden"
  done <<'T'
web rwx rwx — r-- —
datos rwx — rwx r-- —
logs rwx -wx -wx r-- r--
scripts rwx — — r-x —
backups r-x — — rwx —
config rwx r-- r-- r-- —
T
  echo "  Nota: web/ para el servicio web figura rwx en disco (es el dueño, §28.3); la Tabla 27 pide r-x"
  echo "        y se cumple porque los contenedores montan el código en solo lectura (CT-14, ver sección atlas)."
  local m; m="$(efectivo web "$R/logs/auditoria.log")"
  [ "${m:1:1}" = w ] && ok "atlas-web puede agregar a logs/auditoria.log (RF-15)" || mal "atlas-web puede agregar a logs/auditoria.log"
  m="$(efectivo audit "$R/logs/auditoria.log")"
  [ "$m" = "r--" ] && ok "atlas-audit lee y no modifica logs/auditoria.log" || mal "atlas-audit lee y no modifica auditoria.log" "$m"
}

# --- atributos: §28.3 ---------------------------------------------------------
sec_atributos() {
  tit atributos "Atributos inmutable y solo-agregar (§28.3)"
  [[ "$(lsattr -d "$R/config/atlas.conf" 2>/dev/null | cut -d' ' -f1)" == *i* ]] && ok "chattr +i config/atlas.conf" || mal "chattr +i config/atlas.conf"
  [[ "$(lsattr -d "$R/logs/auditoria.log" 2>/dev/null | cut -d' ' -f1)" == *a* ]] && ok "chattr +a logs/auditoria.log" || mal "chattr +a logs/auditoria.log"
  if [[ "$(lsattr -d "$R/logs/auditoria.log" 2>/dev/null | cut -d' ' -f1)" == *a* ]]; then
    ( : > "$R/logs/auditoria.log" ) 2>/dev/null && mal "ni root puede vaciar auditoria.log" || ok "ni root puede vaciar auditoria.log"
    ( echo "# verificacion $(date -Is)" >> "$R/logs/auditoria.log" ) 2>/dev/null && ok "se puede agregar una línea a auditoria.log" || mal "se puede agregar una línea a auditoria.log"
  fi
  if [[ "$(lsattr -d "$R/config/atlas.conf" 2>/dev/null | cut -d' ' -f1)" == *i* ]]; then
    ( touch -c "$R/config/atlas.conf" ) 2>/dev/null && mal "ni root puede modificar atlas.conf" || ok "ni root puede modificar atlas.conf"
  fi
}

# --- ssh y TCP Wrappers: §28.4, DEC-07 ---------------------------------------
sec_ssh() {
  tit ssh "SSH y TCP Wrappers (§28.4, DEC-07)"
  chk "sshd -t (configuración válida)" sshd -t
  local g; g="$(sshd -T -C user=atlasadmin,host=g,addr=172.16.50.10 2>/dev/null)"
  local e; e="$(sshd -T -C user=atlasadmin,host=e,addr=172.16.30.100 2>/dev/null)"
  grep -qx 'permitrootlogin no' <<< "$g" && ok "PermitRootLogin no" || mal "PermitRootLogin no"
  grep -qx 'passwordauthentication no' <<< "$g" && ok "PasswordAuthentication no" || mal "PasswordAuthentication no"
  grep -qx 'pubkeyauthentication yes' <<< "$g" && ok "PubkeyAuthentication yes" || mal "PubkeyAuthentication yes"
  grep -qx 'maxauthtries 3' <<< "$g" && ok "MaxAuthTries 3" || mal "MaxAuthTries 3"
  grep -qx 'allowusers atlasadmin@172.16.50.\*' <<< "$e" && ok "desde VLAN 30 solo rige AllowUsers atlasadmin@172.16.50.* (nadie entra)" || mal "desde VLAN 30: AllowUsers atlasadmin@172.16.50.*"
  grep -qx 'allowgroups gg_soporteti' <<< "$g" && ok "desde VLAN 50: AllowGroups atlas-admin gg_soporteti" || mal "desde VLAN 50: AllowGroups atlas-admin gg_soporteti"
  ldd /usr/sbin/sshd | grep -q libwrap && ok "sshd enlazado con libwrap (TCP Wrappers efectivos)" || mal "sshd enlazado con libwrap"
  grep -qx 'ALL: ALL' /etc/hosts.deny && ok "/etc/hosts.deny: ALL: ALL" || mal "/etc/hosts.deny: ALL: ALL"
  grep -qx 'sshd: 172.16.50.0/255.255.255.0' /etc/hosts.allow && ok "/etc/hosts.allow: sshd: 172.16.50.0/255.255.255.0" || mal "/etc/hosts.allow"
  [ -s /home/atlasadmin/.ssh/authorized_keys ] && ok "atlasadmin tiene clave pública (acceso de emergencia)" || mal "atlasadmin tiene clave pública"
}

# --- firewall: §28.4 + DEC-05 + CT-04 ----------------------------------------
sec_firewall() {
  tit firewall "UFW alineado con la Tabla 44 + DOCKER-USER (DEC-05, CT-04)"
  local s; s="$(ufw status verbose 2>/dev/null)"
  grep -q 'Status: active' <<< "$s" && ok "UFW activo" || mal "UFW activo"
  grep -q 'deny (incoming), allow (outgoing)' <<< "$s" && ok "negar entrante / permitir saliente" || mal "negar entrante / permitir saliente"
  grep -qi 'Logging: on' <<< "$s" && ok "registro activado" || mal "registro activado"
  local regla
  for regla in "22/tcp.*$RED_GESTION" "443/tcp.*$RED_ADMIN" "443/tcp.*$RED_DOCENTES" "443/tcp.*$RED_ESTUDIANTES" \
               "443/tcp.*$RED_VPN_DOCENTES" "445/tcp.*$RED_ADMIN" "445/tcp.*$RED_DOCENTES" "445/tcp.*$IP_DC"; do
    grep -qE "$regla" <<< "$s" && ok "permitido ${regla//.\*/ desde }" || mal "permitido ${regla//.\*/ desde }"
  done
  grep -qE '^(80|139|3306)[/ ]' <<< "$s" && mal "no hay reglas para 80, 139 ni 3306" || ok "no hay reglas para 80, 139 ni 3306"
  local d; d="$(iptables -S DOCKER-USER 2>/dev/null)"
  grep -q 'ctorigdstport 443' <<< "$d" && ok "DOCKER-USER limita el 443 publicado por Docker" || mal "DOCKER-USER limita el 443"
  grep -q -- '-j DROP' <<< "$d" && ok "DOCKER-USER descarta (y registra) el resto" || mal "DOCKER-USER descarta el resto"
}

# --- docker: DEC-02, DEC-21 ---------------------------------------------------
sec_docker() {
  tit docker "Docker (DEC-02, DEC-21, CT-16)"
  chk "servicio docker activo" systemctl is-active --quiet docker
  id -nG atlasadmin | tr ' ' '\n' | grep -qx docker && mal "atlasadmin NO está en el grupo docker" || ok "atlasadmin NO está en el grupo docker"
  [ "$(docker info --format '{{.LoggingDriver}}' 2>/dev/null)" = journald ] && ok "logs de contenedores en journald" || mal "logs de contenedores en journald"
}

# --- atlas: pila, puertos, montajes (Tabla 15, CT-14) ------------------------
sec_atlas() {
  tit atlas "Pila ATLAS (Tabla 15, CT-03, CT-14)"
  chk "atlas.service activo" systemctl is-active --quiet atlas.service
  chk "atlas.service habilitado al arranque" systemctl is-enabled --quiet atlas.service
  local c
  for c in atlas-web atlas-php atlas-db atlas-analysis; do
    [ "$(docker inspect -f '{{.State.Running}}' "$c" 2>/dev/null)" = true ] && ok "contenedor $c corriendo" || mal "contenedor $c corriendo"
  done
  [ "$(docker inspect -f '{{.Config.User}}' atlas-php 2>/dev/null)" = 5002:5002 ] && ok "atlas-php corre como 5002 (atlasweb)" || mal "atlas-php corre como 5002"
  [ "$(docker inspect -f '{{.Config.User}}' atlas-db 2>/dev/null)" = 5003:5003 ] && ok "atlas-db corre como 5003 (atlasdb)" || mal "atlas-db corre como 5003"
  [ "$(docker inspect -f '{{range .Mounts}}{{if eq .Destination "/srv/atlas/web/app"}}{{.RW}}{{end}}{{end}}' atlas-php 2>/dev/null)" = false ] \
    && ok "código montado en solo lectura para atlas-php (Tabla 27 web r-x, CT-14)" || mal "código en solo lectura para atlas-php"
  [ -z "$(docker port atlas-db 2>/dev/null)" ] && ok "atlas-db sin puertos publicados (3306 no accesible)" || mal "atlas-db sin puertos publicados"
  ss -ltnH 'sport = :3306' | grep -q . && mal "nada escucha 3306 en el host" || ok "nada escucha 3306 en el host"
  local p; p="$(docker port atlas-web 2>/dev/null | tr '\n' ' ')"
  [[ "$p" == *"$ATLAS_IP:443"* ]] && ok "atlas-web publica 443 solo en $ATLAS_IP" || mal "atlas-web publica 443 en $ATLAS_IP" "$p"
  curl -fsk --max-time 5 "https://$ATLAS_IP/api/v1/health" | grep -q '"estado":"ok"' && ok "GET /api/v1/health responde ok" || mal "GET /api/v1/health"
  [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "http://$ATLAS_IP/")" = 301 ] && ok "HTTP redirige a HTTPS" || mal "HTTP redirige a HTTPS"
  [ "$(stat -c '%a' "$R/config/atlas.conf")" = 640 ] && ok "atlas.conf modo 640" || mal "atlas.conf modo 640"
  grep -q '=CAMBIAR' "$R/config/atlas.conf" && mal "atlas.conf sin valores de ejemplo" || ok "atlas.conf sin valores de ejemplo"
}

# --- hora: Tabla 35 -----------------------------------------------------------
sec_hora() {
  tit hora "Hora desde el DC (Tabla 35, DEC-R8)"
  chronyc sources 2>/dev/null | grep -q "$IP_DC" && ok "chrony usa $IP_DC" || mal "chrony usa $IP_DC"
  local d; d="$(chronyc tracking 2>/dev/null | awk '/System time/ {print $4}')"
  awk -v d="${d:-999}" 'BEGIN { exit !(d < 1) }' && ok "desfase ${d}s (< 1 s; Kerberos tolera 300 s)" || mal "desfase de hora" "${d:-sin dato}"
}

# --- dominio: Tabla 35, Tabla 36 ---------------------------------------------
sec_dominio() {
  tit dominio "Unión al dominio con SSSD (Tabla 35, Tabla 36)"
  realm list 2>/dev/null | grep -q "domain-name: $ATLAS_DOMINIO" && ok "unido a $ATLAS_DOMINIO" || mal "unido a $ATLAS_DOMINIO"
  realm list 2>/dev/null | grep -q 'client-software: sssd' && ok "cliente SSSD" || mal "cliente SSSD"
  getent group "$AD_GRUPO_SOPORTE" >/dev/null && ok "Linux ve el grupo de AD $AD_GRUPO_SOPORTE" || mal "Linux ve $AD_GRUPO_SOPORTE"
  grep -q '%gg_soporteti;.*atlas-admin,atlas-audit' /etc/security/group.conf && ok "GG_SoporteTI → atlas-admin, atlas-audit (pam_group)" || mal "correspondencia GG_SoporteTI → atlas-admin"
  grep -q pam_group.so /etc/pam.d/sshd && ok "pam_group activo en sshd" || mal "pam_group activo en sshd"
  host "$ATLAS_HOSTNAME.$ATLAS_DOMINIO" "$ATLAS_DNS" 2>/dev/null | grep -q "$ATLAS_IP" && ok "DNS del dominio resuelve $ATLAS_HOSTNAME → $ATLAS_IP" || mal "DNS resuelve $ATLAS_HOSTNAME"
}

# --- samba: Tabla 35, CT-10 --------------------------------------------------
sec_samba() {
  tit samba "Samba (Tabla 35, CT-10)"
  chk "testparm sin errores" testparm -s
  local t; t="$(testparm -s 2>/dev/null)"
  grep -q '^\[administracion\]' <<< "$t" && ok "recurso administracion" || mal "recurso administracion"
  grep -q '^\[docentes\]' <<< "$t" && ok "recurso docentes" || mal "recurso docentes"
  grep -q 'disable netbios = Yes' <<< "$t" && ok "sin NetBIOS (139)" || mal "sin NetBIOS"
  chk "smbd activo" systemctl is-active --quiet smbd
}

# --- registros ---------------------------------------------------------------
sec_registros() {
  tit registros "Registros y auditoría (§28.3, §30.5)"
  grep -q 'Storage=persistent' /etc/systemd/journald.conf.d/atlas.conf 2>/dev/null && ok "journald persistente" || mal "journald persistente"
  auditctl -l 2>/dev/null | grep -q atlas-atributos && ok "auditd registra el uso de chattr" || mal "auditd registra el uso de chattr"
  [ -f /var/log/ufw.log ] && ok "/var/log/ufw.log existe" || mal "/var/log/ufw.log existe"
}

# --- sudo: DEC-21 -------------------------------------------------------------
sec_sudo() {
  tit sudo "sudo acotado (DEC-21)"
  chk "sudoers válido" visudo -c
  local l; l="$(sudo -l -U atlasadmin 2>/dev/null)"
  grep -q '(ALL) ALL\|(ALL : ALL) ALL' <<< "$l" && mal "atlasadmin NO tiene sudo total" || ok "atlasadmin NO tiene sudo total"
  grep -q '/usr/local/sbin/atlas-ctl' <<< "$l" && ok "atlasadmin puede operar ATLAS con atlas-ctl" || mal "atlasadmin puede usar atlas-ctl"
  [ "$(stat -c '%U %a' /usr/local/sbin/atlas-ctl 2>/dev/null)" = "root 755" ] && ok "atlas-ctl es de root y no editable por otros" || mal "atlas-ctl es de root"
}

echo "ATLAS — verificación de $(hostname) · $(date -Is)"
SECCIONES=("$@"); [ ${#SECCIONES[@]} -eq 0 ] && SECCIONES=(usuarios permisos atributos ssh firewall docker atlas hora dominio samba registros sudo)
for s in "${SECCIONES[@]}"; do "sec_$s"; done
printf '\nResultado: %d PASS · %d FAIL\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
