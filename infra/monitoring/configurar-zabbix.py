#!/usr/bin/env python3
"""ATLAS — deja Zabbix configurado por su API (§30.5, Tablas 46 y 47; DEC-19).

Se puede correr más de una vez: lo que ya existe no se duplica. Hace:
  1. Cambia la contraseña inicial del usuario Admin (zabbix) por la de monitoreo.conf.
  2. Grupo «ATLAS · servidores» con atlas-srv01 (Linux) y atlas-dc01 (Windows), cada uno
     con la plantilla oficial de su sistema y los umbrales de la Tabla 47: alerta al 80 %
     de CPU, memoria y disco.
  3. Escenario web «atlas-salud»: pide https://172.16.40.10/api/v1/health cada minuto.
     Disparadores: ATLAS no responde, y ATLAS tarda más de 3 s (RNF-03).
  4. Servicio «ATLAS · plataforma web» y SLA del 99 % (RNF-02): Zabbix calcula la
     disponibilidad real de cada día con los problemas del escenario web.

Uso:  ZBX_ADMIN_PASSWORD=... python3 configurar-zabbix.py
      (14-monitoreo.sh lo corre leyendo /srv/atlas/config/monitoreo.conf; la contraseña no
       se imprime en ningún momento)
Variables opcionales: ZBX_URL, SRV_IP, DC_IP, ATLAS_URL.
"""

import json
import os
import sys
import time
import urllib.error
import urllib.request

URL = os.environ.get("ZBX_URL", "http://127.0.0.1:8080").rstrip("/") + "/api_jsonrpc.php"
CLAVE = os.environ.get("ZBX_ADMIN_PASSWORD") or sys.exit("Falta ZBX_ADMIN_PASSWORD.")
SRV_IP = os.environ.get("SRV_IP", "172.16.40.10")
DC_IP = os.environ.get("DC_IP", "172.16.40.20")
ATLAS_URL = os.environ.get("ATLAS_URL", "https://172.16.40.10").rstrip("/")
GRUPO = "ATLAS · servidores"
ESCENARIO = "atlas-salud"
TAG = {"tag": "servicio", "value": "atlas-web"}
# Tabla 47: alerta al llegar al 80 % de CPU, memoria y disco.
UMBRALES = [
    {"macro": "{$CPU.UTIL.CRIT}", "value": "80"},
    {"macro": "{$MEMORY.UTIL.MAX}", "value": "80"},
    {"macro": "{$VFS.FS.PUSED.MAX.WARN}", "value": "80"},
    {"macro": "{$VFS.FS.PUSED.MAX.CRIT}", "value": "90"},
]
token = None
_id = 0


TRANSITORIOS = ("Database error", "Connection refused", "Lost connection", "Connection to Zabbix server")


def api(metodo, params, intentos=12):
    global _id
    for intento in range(intentos):
        _id += 1
        cuerpo = json.dumps({"jsonrpc": "2.0", "method": metodo, "params": params, "id": _id}).encode()
        cabeceras = {"Content-Type": "application/json-rpc"}
        if token and metodo not in ("user.login", "apiinfo.version"):   # estos dos van sin sesión
            cabeceras["Authorization"] = f"Bearer {token}"
        with urllib.request.urlopen(urllib.request.Request(URL, data=cuerpo, headers=cabeceras), timeout=30) as r:
            datos = json.loads(r.read())
        if "error" not in datos:
            return datos["result"]
        detalle = datos["error"].get("data") or datos["error"].get("message")
        # Recién instalado, zabbix-server todavía escribe en su base y la API puede devolver
        # «Database error occurred» o «Connection refused» mientras termina de arrancar: se
        # reintenta unos segundos después (hasta un minuto).
        if not any(t in str(detalle) for t in TRANSITORIOS) or intento == intentos - 1:
            raise RuntimeError(f"{metodo}: {detalle}")
        time.sleep(5)


def esperar_api():
    for _ in range(90):
        try:
            return api("apiinfo.version", {})
        except (urllib.error.URLError, ConnectionError, RuntimeError, json.JSONDecodeError):
            time.sleep(4)
    sys.exit("La API de Zabbix no responde (¿están levantados zabbix-web y zabbix-server?).")


def entrar():
    global token
    try:
        token = api("user.login", {"username": "Admin", "password": CLAVE})
        print("  Admin ya tenía la contraseña de monitoreo.conf")
    except RuntimeError:
        token = api("user.login", {"username": "Admin", "password": "zabbix"})
        api("user.update", {"userid": "1", "current_passwd": "zabbix", "passwd": CLAVE})
        token = api("user.login", {"username": "Admin", "password": CLAVE})
        print("  Contraseña inicial de Admin reemplazada (la de monitoreo.conf)")


def uno(metodo, filtro, salida="extend"):
    r = api(metodo, {"filter": filtro, "output": salida})
    return r[0] if r else None


def grupo():
    g = uno("hostgroup.get", {"name": GRUPO})
    return g["groupid"] if g else api("hostgroup.create", {"name": GRUPO})["groupids"][0]


def plantilla(nombre):
    t = uno("template.get", {"host": nombre})
    if not t:
        sys.exit(f"No encuentro la plantilla «{nombre}» en Zabbix.")
    return t["templateid"]


def host(nombre, visible, ip, plantilla_id, grupo_id, macros=()):
    h = uno("host.get", {"host": nombre})
    datos = {
        "name": visible, "groups": [{"groupid": grupo_id}], "templates": [{"templateid": plantilla_id}],
        "macros": UMBRALES + list(macros), "tags": [{"tag": "proyecto", "value": "atlas"}],
    }
    if h:
        api("host.update", {"hostid": h["hostid"], **datos})
        print(f"  {nombre}: actualizado (umbrales al 80 %)")
        return h["hostid"]
    hid = api("host.create", {"host": nombre, **datos, "interfaces": [
        {"type": 1, "main": 1, "useip": 1, "ip": ip, "dns": "", "port": "10050"}]})["hostids"][0]
    print(f"  {nombre}: creado, agente en {ip}:10050")
    return hid


def escenario(hostid):
    if not uno("httptest.get", {"name": ESCENARIO, "hostid": hostid}):
        api("httptest.create", {
            "name": ESCENARIO, "hostid": hostid, "delay": "1m", "retries": 2, "verify_peer": 0, "verify_host": 0,
            "tags": [TAG],
            "steps": [{"name": "health", "no": 1, "url": f"{ATLAS_URL}/api/v1/health", "status_codes": "200",
                       "required": '"estado":"ok"', "timeout": "10s"}],
        })
        print(f"  Escenario web {ESCENARIO}: {ATLAS_URL}/api/v1/health cada minuto")
    disparadores = [
        ("ATLAS no responde (salud de la plataforma)", f"last(/atlas-srv01/web.test.fail[{ESCENARIO}])<>0", 4,
         "El escenario atlas-salud falló: la plataforma no responde o la base no está conectada."),
        ("ATLAS tarda más de 3 s en responder (RNF-03)", f"avg(/atlas-srv01/web.test.time[{ESCENARIO},health,resp],5m)>3", 2,
         "Promedio de 5 minutos del tiempo de respuesta de /api/v1/health por encima de 3 s (Tabla 47)."),
    ]
    for descripcion, expresion, prioridad, comentario in disparadores:
        if not uno("trigger.get", {"description": descripcion}):
            api("trigger.create", {"description": descripcion, "expression": expresion, "priority": prioridad,
                                   "comments": comentario, "tags": [TAG]})
            print(f"  Disparador: {descripcion}")


def disponibilidad():
    if not uno("service.get", {"name": "ATLAS · plataforma web"}):
        api("service.create", {"name": "ATLAS · plataforma web", "algorithm": 1, "sortorder": 0, "tags": [TAG],
                               "problem_tags": [{"tag": "servicio", "operator": 0, "value": "atlas-web"}]})
        print("  Servicio: ATLAS · plataforma web")
    if not uno("sla.get", {"name": "ATLAS · disponibilidad (RNF-02)"}):
        api("sla.create", {"name": "ATLAS · disponibilidad (RNF-02)", "slo": "99", "period": 0,
                           "timezone": "America/Montevideo", "status": 1,
                           "effective_date": int(time.time()) // 86400 * 86400,
                           "service_tags": [{"tag": "servicio", "operator": 0, "value": "atlas-web"}],
                           "description": "Tabla 47: 99 % o más durante las pruebas. Período diario."})
        print("  SLA: 99 %, diario (Servicios → SLA report)")


print(f"Zabbix {esperar_api()} en {URL}")
entrar()
gid = grupo()
# El agente de srv01 corre en un contenedor que ve el disco del servidor en /hostfs (solo
# lectura): se miden esos sistemas de archivos y no los del propio contenedor.
srv = host("atlas-srv01", "atlas-srv01 (Linux, VLAN 40)", SRV_IP, plantilla("Linux by Zabbix agent"), gid,
           [{"macro": "{$VFS.FS.FSNAME.MATCHES}", "value": "^/hostfs"}])
host("atlas-dc01", "atlas-dc01 (Windows, VLAN 40)", DC_IP, plantilla("Windows by Zabbix agent"), gid)
escenario(srv)
disponibilidad()
print("Listo. Interfaz: túnel SSH desde la VLAN 50 → http://127.0.0.1:8080 (usuario Admin).")
