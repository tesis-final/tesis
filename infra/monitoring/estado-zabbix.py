#!/usr/bin/env python3
"""ATLAS — estado del monitoreo, para la evidencia y para verificar.sh (§30.5, Tabla 47).

Solo lee (no cambia nada). Muestra, por la API de Zabbix:
  · si cada agente responde y los últimos valores de CPU, memoria y disco;
  · el escenario web atlas-salud: último resultado y tiempo de respuesta;
  · los problemas abiertos y el SLA del 99 % de los últimos días;
  · que la contraseña inicial «zabbix» ya no sirve.
Sale con código 1 si algo de lo que tiene que estar no está.

Uso:  ZBX_ADMIN_PASSWORD=... python3 estado-zabbix.py      (ZBX_URL opcional)
"""

import json
import os
import sys
import time
import urllib.request

URL = os.environ.get("ZBX_URL", "http://127.0.0.1:8080").rstrip("/") + "/api_jsonrpc.php"
CLAVE = os.environ.get("ZBX_ADMIN_PASSWORD") or sys.exit("Falta ZBX_ADMIN_PASSWORD.")
token = None
fallas = []


def api(metodo, params):
    cab = {"Content-Type": "application/json-rpc"}
    if token and metodo not in ("user.login", "apiinfo.version"):
        cab["Authorization"] = f"Bearer {token}"
    cuerpo = json.dumps({"jsonrpc": "2.0", "method": metodo, "params": params, "id": 1}).encode()
    with urllib.request.urlopen(urllib.request.Request(URL, data=cuerpo, headers=cab), timeout=30) as r:
        datos = json.loads(r.read())
    if "error" in datos:
        raise RuntimeError(datos["error"].get("data") or datos["error"].get("message"))
    return datos["result"]


def control(ok, texto):
    print(f"  {'PASS' if ok else 'FAIL'}  {texto}")
    if not ok:
        fallas.append(texto)


def ultimo(hostid, clave):
    r = api("item.get", {"hostids": hostid, "search": {"key_": clave}, "output": ["key_", "lastvalue", "lastclock", "units"], "webitems": True,
                         "sortfield": "key_", "limit": 1})
    return r[0] if r and r[0]["lastclock"] != "0" else None


try:
    api("user.login", {"username": "Admin", "password": "zabbix"})
    vieja = True
except RuntimeError:
    vieja = False
token = api("user.login", {"username": "Admin", "password": CLAVE})
print(f"Zabbix {api('apiinfo.version', {})} · {time.strftime('%Y-%m-%d %H:%M:%S %z')}")
control(not vieja, "la contraseña inicial de Admin («zabbix») ya no entra")

print("\n[agentes]")
hosts = api("host.get", {"filter": {"host": ["atlas-srv01", "atlas-dc01"]}, "output": ["hostid", "host"],
                         "selectInterfaces": ["ip", "available", "error"]})
for h in sorted(hosts, key=lambda x: x["host"]):
    i = h["interfaces"][0]
    control(i["available"] == "1", f"{h['host']} ({i['ip']}:10050) responde{'' if i['available'] == '1' else ' — ' + (i['error'] or 'sin datos todavía')}")
    for clave, nombre in (("system.cpu.util", "CPU"), ("vm.memory.util", "memoria"), ("vfs.fs.dependent.size[/hostfs,pused]", "disco /"),
                          ("vfs.fs.dependent.size[C:,pused]", "disco C:")):
        it = ultimo(h["hostid"], clave)
        if it:
            print(f"        {nombre:9} {float(it['lastvalue']):6.1f} %  (umbral de alerta 80 %)")
control(len(hosts) == 2, "atlas-srv01 y atlas-dc01 están dados de alta")

print("\n[escenario web atlas-salud]")
srv = next((h for h in hosts if h["host"] == "atlas-srv01"), None)
if srv:
    falla = ultimo(srv["hostid"], "web.test.fail[atlas-salud]")
    tiempo = ultimo(srv["hostid"], "web.test.time[atlas-salud,health,resp]")
    codigo = ultimo(srv["hostid"], "web.test.rspcode[atlas-salud,health]")
    control(falla is not None and falla["lastvalue"] == "0", "último chequeo de /api/v1/health sin fallas")
    if codigo:
        print(f"        código HTTP {codigo['lastvalue']}")
    if tiempo:
        control(float(tiempo["lastvalue"]) <= 3, f"tiempo de respuesta {float(tiempo['lastvalue']) * 1000:.0f} ms (meta ≤ 3 s, RNF-03)")

print("\n[problemas abiertos]")
problemas = api("problem.get", {"output": ["name", "severity", "clock"], "recent": False, "sortfield": ["eventid"], "sortorder": "DESC"})
for p in problemas[:15]:
    print(f"        {time.strftime('%d/%m %H:%M', time.localtime(int(p['clock'])))}  {p['name']}")
print(f"        total: {len(problemas)}")

print("\n[SLA]")
sla = api("sla.get", {"filter": {"name": "ATLAS · disponibilidad (RNF-02)"}, "output": ["slaid", "slo"]})
control(bool(sla), "SLA «ATLAS · disponibilidad (RNF-02)» definido")
if sla:
    rep = api("sla.getsli", {"slaid": sla[0]["slaid"], "periods": 7})
    for periodo, filas in zip(rep.get("periods", []), rep.get("sli", [])):
        for fila in filas:
            print(f"        {time.strftime('%d/%m/%Y', time.localtime(periodo['period_from']))}  SLI {fila['sli']:.3f} %  (SLO {sla[0]['slo']} %)")

print(f"\nResultado: {'OK' if not fallas else str(len(fallas)) + ' control(es) en FAIL'}")
sys.exit(1 if fallas else 0)
