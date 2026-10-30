"""ATLAS — tiempo de respuesta de las consultas más frecuentes (RNF-03).

Criterio del PDF (Tabla H29): "Tiempo de respuesta igual o menor a 3 segundos en las
operaciones de consulta más frecuentes". Se hace cada consulta N veces con la sesión
de cada rol y se informa mínimo, mediana, percentil 95 y máximo. Aprobada si el
percentil 95 de cada consulta es de 3000 ms o menos.

Uso: python medir.py <url_base> <clave_demo> [repeticiones]
     (datos de DEMOSTRACIÓN cargados con probar-local.sh; el certificado local es
     autofirmado, por eso no se verifica)
"""

import json
import ssl
import statistics
import sys
import time
import urllib.request
from http.cookiejar import CookieJar

BASE, CLAVE = sys.argv[1].rstrip("/"), sys.argv[2]
N = int(sys.argv[3]) if len(sys.argv) > 3 else 20
LIMITE_MS = 3000
CTX = ssl._create_unverified_context()


def sesion(correo):
    abridor = urllib.request.build_opener(
        urllib.request.HTTPSHandler(context=CTX), urllib.request.HTTPCookieProcessor(CookieJar())
    )
    datos = json.dumps({"correo": correo, "contrasena": CLAVE}).encode()
    pedido = urllib.request.Request(
        BASE + "/api/v1/auth/login", data=datos,
        headers={"Content-Type": "application/json", "Accept": "application/json"},
    )
    inicio = time.perf_counter()
    with abridor.open(pedido) as r:
        r.read()
    return abridor, (time.perf_counter() - inicio) * 1000


def medir(abridor, ruta):
    tiempos = []
    for _ in range(N):
        pedido = urllib.request.Request(BASE + "/api/v1" + ruta, headers={"Accept": "application/json"})
        inicio = time.perf_counter()
        with abridor.open(pedido) as r:
            r.read()
            assert r.status == 200, f"{ruta}: {r.status}"
        tiempos.append((time.perf_counter() - inicio) * 1000)
    return tiempos


def p95(valores):
    ordenados = sorted(valores)
    return ordenados[max(0, round(0.95 * len(ordenados)) - 1)]


docente, ms_login_doc = sesion("docente.demo@atlas.local")
estudiante, ms_login_est = sesion("ana.demo@atlas.local")
grupos = json.loads(docente.open(urllib.request.Request(BASE + "/api/v1/grupos")).read())
g = grupos[0]["id"]
miembros = json.loads(docente.open(urllib.request.Request(f"{BASE}/api/v1/grupos/{g}/miembros")).read())
estudiantes = [m for m in miembros if isinstance(m, dict) and m.get("rol") == "ESTUDIANTE" and "id" in m]

consultas = [
    ("docente", "Mis actividades", "/actividades"),
    ("docente", "Dónde intervenir / análisis del grupo", f"/docente/grupos/{g}/analisis"),
    ("docente", "Consulta guiada (grupo + período)", f"/docente/grupos/{g}/analisis?desde=2026-01-01&hasta=2026-12-31"),
    ("docente", "Reportes", "/reportes"),
    ("estudiante", "Actividades del estudiante", "/estudiante/actividades"),
    ("estudiante", "Sesión actual", "/auth/me"),
]
if estudiantes:
    consultas.insert(3, ("docente", "Perfil de un estudiante", f"/docente/estudiantes/{estudiantes[0]['id']}/perfil"))

print(f"# {N} repeticiones por consulta · límite RNF-03: {LIMITE_MS} ms (percentil 95)")
print(f"Inicio de sesión (una vez): docente {ms_login_doc:.0f} ms · estudiante {ms_login_est:.0f} ms")
print(f"{'Rol':<11}{'Consulta':<40}{'mín':>7}{'mediana':>9}{'p95':>7}{'máx':>7}  Resultado")
fallas = 0
for rol, nombre, ruta in consultas:
    t = medir(docente if rol == "docente" else estudiante, ruta)
    ok = p95(t) <= LIMITE_MS
    fallas += 0 if ok else 1
    print(f"{rol:<11}{nombre:<40}{min(t):>7.0f}{statistics.median(t):>9.0f}{p95(t):>7.0f}{max(t):>7.0f}  {'PASS' if ok else 'FAIL'}")
print(f"\nResultado: {len(consultas) - fallas} PASS · {fallas} FAIL")
sys.exit(1 if fallas else 0)
