#!/usr/bin/env bash
# =============================================================================
# ATLAS · Fase 6 · Paso 3 — Directorios, permisos, ACL y atributos
# PDF §28.3 (dueños y modos, ACL, chattr) + Tabla 27 (resultado a lograr, DEC-06).
#
# Cómo se llega a la Tabla 27 (ver README, sección "Permisos"):
#   · dueños y modos: literales de §28.3;
#   · las 5 ACL de §28.3, ajustadas a lo que pide la Tabla 27 (DEC-06);
#   · ACL agregadas donde la Tabla 27 da acceso a alguien que no es dueño;
#   · la columna "admin" es el GRUPO atlas-admin (así también vale para
#     GG_SoporteTI, que entra a ese grupo por la Tabla 36), no solo el dueño;
#   · "--x" en /srv/atlas para que cada cuenta pueda llegar a SU carpeta;
#   · "r--" sobre un directorio se implementa como r-x (sin x no se puede
#     leer nada de adentro);
#   · web/ para atlasweb: la Tabla 27 pide r-x y §28.3 lo hace dueño (rwx).
#     Se cumplen las dos cosas: el dueño sigue siendo atlasweb, y los
#     contenedores montan el código en SOLO LECTURA (docker-compose.yml, ":ro"),
#     así el servicio web no puede modificar su propio código (CT-14).
#
# Uso: sudo ./03-directorios-permisos.sh          (crea y aplica todo)
#      sudo ./03-directorios-permisos.sh --acl    (solo reaplica ACL, p. ej. tras un despliegue)
# =============================================================================
source "$(dirname "$0")/lib/comun.sh"
requiere_root

R="$ATLAS_ROOT"
SOLO_ACL=no; [ "${1:-}" = "--acl" ] && SOLO_ACL=si

dir() {  # ruta dueño:grupo modo
  install -d -o "${2%%:*}" -g "${2##*:}" -m "$3" "$1"
  chown "$2" "$1"; chmod "$3" "$1"
}

# acl RUTA ENTRADA...  → aplica a la carpeta, a lo que ya tiene adentro y como
# ACL por defecto (lo que se cree después hereda lo mismo, §28.3 "-d").
acl() {
  local ruta="$1"; shift
  local e
  for e in "$@"; do
    # "X" mayúscula: ejecución solo para directorios y para lo que ya era ejecutable.
    setfacl -R -m "$e" "$ruta"
    # ACL por defecto: solo existen en directorios.
    find "$ruta" -type d -exec setfacl -d -m "$e" {} +
  done
}

if [ "$SOLO_ACL" = no ]; then
  paso "Árbol de §28.3"
  command -v setfacl >/dev/null || error "Falta el paquete acl (paso 1)."
  dir "$R"          atlasadmin:atlas-admin 750
  dir "$R/web"      atlasweb:atlas-web     750
  dir "$R/web/public" atlasweb:atlas-web   755
  dir "$R/web/app"  atlasweb:atlas-web     750
  dir "$R/web/analysis" atlasweb:atlas-web 750   # servicio atlas-analysis (fase-02 §3)
  dir "$R/datos"    atlasdb:atlas-db       770
  dir "$R/logs"     atlasadmin:atlas-admin 770
  dir "$R/scripts"  atlasadmin:atlas-admin 750
  dir "$R/config"   atlasadmin:atlas-admin 750
  dir "$R/config/tls" atlasadmin:atlas-admin 750
  dir "$R/backups"  atlasbkp:atlas-backup  700

  # Archivos que §28.3 protege con atributos: tienen que existir antes del chattr.
  [ -e "$R/logs/auditoria.log" ] || install -m 660 -o atlasadmin -g atlas-admin /dev/null "$R/logs/auditoria.log"
  [ -e "$R/config/atlas.conf" ]  || install -m 640 -o atlasadmin -g atlas-admin /dev/null "$R/config/atlas.conf"
fi

# Los atributos impiden cambiar ACL: se sacan un momento y se vuelven a poner al final.
chattr -i "$R/config/atlas.conf" 2>/dev/null || true
chattr -a "$R/logs/auditoria.log" 2>/dev/null || true

paso "ACL para llegar a la Tabla 27"
# /srv/atlas (750): solo atravesar, para que cada uno llegue a lo suyo (DEC-06).
setfacl -m g:atlas-web:--x,g:atlas-db:--x,g:atlas-backup:--x,g:atlas-audit:--x "$R"

# web/        admin rwx · web r-x (dueño + montaje :ro, CT-14) · db — · backup r-- · audit —
acl "$R/web" g:atlas-admin:rwX g:atlas-backup:rX

# datos/      admin rwx · web — · db rwx (dueño) · backup r-- · audit —
#   PDF: setfacl -m u:atlasbkp:rx /srv/atlas/datos  → por grupo, para que también
#   valga para quien esté en atlas-backup.
acl "$R/datos" g:atlas-admin:rwX g:atlas-backup:rX

# logs/       admin rwx (dueño) · web -wx · db -wx · backup r-- · audit r--
#   PDF: u:atlasweb:rwx y g:atlas-audit:rx (+ por defecto). La Tabla 27 pide -wx
#   para web: puede crear y escribir sus archivos pero no listar los de los demás.
setfacl -R -x u:atlasweb "$R/logs" 2>/dev/null || true
find "$R/logs" -type d -exec setfacl -d -x u:atlasweb {} + 2>/dev/null || true
acl "$R/logs" g:atlas-admin:rwX g:atlas-web:-wX g:atlas-db:-wX g:atlas-backup:rX g:atlas-audit:rX
# El servicio web agrega líneas a auditoria.log (RF-15): escritura sobre ese archivo.
setfacl -m g:atlas-admin:rw-,g:atlas-web:rw-,g:atlas-db:---,g:atlas-backup:r--,g:atlas-audit:r-- "$R/logs/auditoria.log"

# scripts/    admin rwx (dueño) · backup r-x
acl "$R/scripts" g:atlas-admin:rwX g:atlas-backup:rX

# backups/    admin r-x · backup rwx (dueño). El administrador NO escribe acá (p. 52).
acl "$R/backups" g:atlas-admin:rX

# config/     admin rwx (dueño) · web r-- · db r-- · backup r--
acl "$R/config" g:atlas-admin:rwX g:atlas-web:rX g:atlas-db:rX g:atlas-backup:rX

paso "Atributos (§28.3)"
if chattr +i "$R/config/atlas.conf" 2>/dev/null && chattr +a "$R/logs/auditoria.log" 2>/dev/null; then
  lsattr "$R/config/atlas.conf" "$R/logs/auditoria.log"
else
  aviso "El sistema de archivos no soporta chattr acá (¿contenedor/overlay?). En la VM con ext4 sí."
fi

paso "Listo. Verificar con: sudo ./verificar.sh permisos"
