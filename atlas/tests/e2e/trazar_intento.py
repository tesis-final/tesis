"""ATLAS — seguimiento de un intento de punta a punta (devolución de Base de Datos, Hito 2).

Pedido de la devolución: «Usen una cuenta de prueba para iniciar una actividad, cambiar una
respuesta y finalizarla. Anoten qué puntaje esperan. Después busquen ese intento en la base y
muestren la respuesta final, el cambio registrado en las interacciones y el único puntaje
guardado. Comprueben que el docente ve ese mismo valor en el informe».

Qué hace, en este orden:
  1. Con la sesión de la docente lee la actividad (qué opción es la correcta) y arma un plan:
     la pregunta 1 se contesta mal y después se CAMBIA a la correcta; la 2 bien; la 3 mal; el
     resto bien. Con ese plan calcula el puntaje esperado ANTES de empezar.
  2. Con la cuenta del estudiante resuelve la actividad en la pantalla real (Chromium), clic
     por clic, y lee el puntaje que muestra la pantalla de resultado.
  3. Busca ese intento en MySQL: estado y tiempos, respuesta final de cada pregunta, todas las
     interacciones (con el CAMBIO_OPCION), y cuántas filas hay en resultados (debe ser una).
  4. Entra como la docente y busca el mismo intento en el informe (Reportes) por su número.
  5. Compara los cuatro valores y termina con código 0 solo si coinciden.

Uso:  python trazar_intento.py <url_base> <carpeta_salida> <clave_demo> [correo_estudiante] [título]
      ATLAS_MYSQL="docker exec -i atlas-db sh -c 'exec mysql -uroot -p\"$MYSQL_ROOT_PASSWORD\" atlas_db'"
      (en atlas-srv01 se corre con sudo; la contraseña de root no se escribe: la lee el contenedor)
Datos: cuentas de DEMOSTRACIÓN (probar-local.sh) o las de prueba del laboratorio.
"""

import json
import os
import re
import shlex
import subprocess
import sys
import time

from playwright.sync_api import sync_playwright

BASE, SALIDA, CLAVE = sys.argv[1].rstrip("/"), sys.argv[2], sys.argv[3]
ESTUDIANTE = sys.argv[4] if len(sys.argv) > 4 else "ana.demo@atlas.local"
TITULO = sys.argv[5] if len(sys.argv) > 5 else "Problemas con porcentajes"
DOCENTE = os.environ.get("ATLAS_DOCENTE", "docente.demo@atlas.local")
MYSQL = os.environ.get(
    "ATLAS_MYSQL",
    "docker exec -i atlas-db sh -c 'exec mysql -uroot -p\"$MYSQL_ROOT_PASSWORD\" --default-character-set=utf8mb4 atlas_db'",
)
os.makedirs(SALIDA, exist_ok=True)
informe = []


def linea(texto=""):
    print(texto)
    informe.append(texto)


def sql(consulta, tabla=True):
    """Ejecuta una consulta en la base (como root dentro del contenedor) y devuelve el texto."""
    args = ["-t"] if tabla else ["-N", "-B"]
    comando = shlex.split(MYSQL)
    # Las opciones de formato se agregan al final del comando de mysql.
    comando[-1] = comando[-1] + " " + " ".join(args)
    r = subprocess.run(comando, input=consulta, capture_output=True, text=True, check=False)
    salida = "\n".join(l for l in r.stdout.splitlines() if "Using a password" not in l)
    if r.returncode != 0:
        raise RuntimeError(r.stderr.strip())
    return salida


def entrar(contexto, correo):
    page = contexto.new_page()
    page.goto(BASE + "/#/login")
    page.fill("#correo", correo)
    page.fill("#contrasena", CLAVE)
    page.click("button[type=submit]")
    page.wait_for_selector("#sesion button")
    return page


def api(page, ruta):
    return page.evaluate("async (r) => (await fetch('/api/v1' + r, {headers: {Accept: 'application/json'}})).json()", ruta)


inicio = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
linea(f"# Seguimiento de un intento de punta a punta · {inicio}")
linea(f"# ATLAS en {BASE} · estudiante {ESTUDIANTE} · actividad «{TITULO}»")

with sync_playwright() as p:
    nav = p.chromium.launch(executable_path=os.environ.get("PW_CHROMIUM") or None, args=["--no-sandbox"])

    # 1. Plan y puntaje esperado (la docente ve cuál es la opción correcta)
    ctx_doc = nav.new_context(ignore_https_errors=True, locale="es-UY", viewport={"width": 1280, "height": 900})
    doc = entrar(ctx_doc, DOCENTE)
    actividad = next((a for a in api(doc, "/actividades") if a["titulo"] == TITULO and a["estado"] == "PUBLICADA"), None)
    if not actividad:
        sys.exit(f"No hay una actividad publicada con el título «{TITULO}».")
    detalle = api(doc, f"/actividades/{actividad['id']}")
    plan = []
    for i, pregunta in enumerate(detalle["preguntas"]):
        correcta = next(o for o in pregunta["opciones"] if o["correcta"])
        incorrecta = next(o for o in pregunta["opciones"] if not o["correcta"])
        if i == 0:
            plan.append({"pregunta": pregunta, "clics": [incorrecta, correcta], "final": correcta})
        elif i == 2:
            plan.append({"pregunta": pregunta, "clics": [incorrecta], "final": incorrecta})
        else:
            plan.append({"pregunta": pregunta, "clics": [correcta], "final": correcta})
    correctas = sum(1 for x in plan if x["final"]["correcta"])
    esperado = round(100 * correctas / len(plan), 2)
    linea()
    linea("== 1. Plan y puntaje esperado (antes de empezar)")
    for i, x in enumerate(plan, 1):
        recorrido = " → ".join(f"«{o['texto']}»{' (correcta)' if o['correcta'] else ''}" for o in x["clics"])
        linea(f"Pregunta {i}: {recorrido}")
    linea(f"Puntaje esperado: {correctas} correctas de {len(plan)} = {esperado}")

    # 2. El estudiante resuelve en la pantalla real
    ctx_est = nav.new_context(ignore_https_errors=True, locale="es-UY", viewport={"width": 390, "height": 844})
    est = entrar(ctx_est, ESTUDIANTE)
    est.goto(BASE + f"/#/resolver/{actividad['id']}")
    est.wait_for_selector(".pregunta")
    for i, x in enumerate(plan):
        for opcion in x["clics"]:
            with est.expect_response(lambda r: "/respuestas/" in r.url and r.request.method == "PUT"):
                est.check(f'.opcion input[value="{opcion["id"]}"]')
            est.wait_for_timeout(250)
        if i == 0:
            est.screenshot(path=f"{SALIDA}/1-estudiante-cambia-respuesta.png", full_page=True)
        if i < len(plan) - 1:
            est.click("button:has-text('Siguiente')")
            est.wait_for_selector(f"text=Pregunta {i + 2} de")
    with est.expect_navigation(url=re.compile(r"#/resultado/\d+")):
        est.click(".pregunta button:has-text('Finalizar')")
    est.wait_for_selector("text=Respuestas correctas")
    intento_id = int(re.search(r"#/resultado/(\d+)", est.url).group(1))
    texto = est.inner_text("#app")
    en_pantalla = float(re.search(r"([\d.,]+)\s*/\s*100", texto).group(1).replace(",", "."))
    est.screenshot(path=f"{SALIDA}/2-estudiante-resultado.png", full_page=True)
    linea()
    linea("== 2. Pantalla del estudiante")
    linea(f"Intento número {intento_id} finalizado. Puntaje en pantalla: {en_pantalla}")

    # 3. La base de datos
    linea()
    linea(f"== 3. El intento {intento_id} en MySQL")
    linea("-- intentos (lo pone el servidor: inicio, fin y estado)")
    linea(sql(f"SELECT id, usuario_id, actividad_id, numero_intento, estado, iniciado_en, finalizado_en, duracion_seg FROM intentos WHERE id = {intento_id};"))
    linea("-- respuestas: la opción FINAL de cada pregunta")
    linea(sql(f"""SELECT p.orden AS pregunta, o.texto AS opcion_final, o.es_correcta, r.tiempo_seg, r.respondido_en
                    FROM respuestas r JOIN preguntas p ON p.id = r.pregunta_id JOIN opciones o ON o.id = r.opcion_id
                   WHERE r.intento_id = {intento_id} ORDER BY p.orden;"""))
    linea("-- interacciones: el proceso, en orden (acá queda el cambio de respuesta)")
    linea(sql(f"""SELECT i.secuencia, i.tipo, p.orden AS pregunta, o.texto AS opcion, i.ocurrido_en
                    FROM interacciones i LEFT JOIN preguntas p ON p.id = i.pregunta_id LEFT JOIN opciones o ON o.id = i.opcion_id
                   WHERE i.intento_id = {intento_id} ORDER BY i.secuencia;"""))
    linea("-- resultados: un único puntaje guardado")
    linea(sql(f"SELECT id, intento_id, correctas, total_preguntas, puntaje, calculado_en FROM resultados WHERE intento_id = {intento_id};"))
    filas_resultado = int(sql(f"SELECT COUNT(*) FROM resultados WHERE intento_id = {intento_id};", tabla=False).strip())
    en_base = float(sql(f"SELECT puntaje FROM resultados WHERE intento_id = {intento_id};", tabla=False).strip())
    cambios = int(sql(f"""SELECT COUNT(*) FROM interacciones i JOIN preguntas p ON p.id = i.pregunta_id
                          WHERE i.intento_id = {intento_id} AND i.tipo = 'CAMBIO_OPCION' AND p.orden = 1;""", tabla=False).strip())
    final_p1 = sql(f"""SELECT o.es_correcta FROM respuestas r JOIN preguntas p ON p.id = r.pregunta_id JOIN opciones o ON o.id = r.opcion_id
                        WHERE r.intento_id = {intento_id} AND p.orden = 1;""", tabla=False).strip()

    # 4. El informe de la docente
    doc.goto(BASE + "/#/reportes")
    doc.wait_for_selector("th:has-text('Tiempo activo')")
    informe_docente = api(doc, "/reportes")
    fila = next((f for f in informe_docente["filas"] if int(f["intento_id"]) == intento_id), None)
    en_informe = float(fila["puntaje"]) if fila else None
    doc.screenshot(path=f"{SALIDA}/3-docente-informe.png", full_page=False)
    linea()
    linea("== 4. Informe de la docente (Reportes → Intentos finalizados)")
    if fila:
        linea(f"Intento {intento_id}: {fila['estudiante_nombre']} {fila['estudiante_apellido']} · {fila['actividad_titulo']} · "
              f"puntaje {en_informe} · {fila['correctas']} de {fila['total_preguntas']} · tiempo total {fila['duracion_seg']} s, activo {fila['duracion_activa_seg']} s")
    else:
        linea(f"El intento {intento_id} no aparece en el informe.")
    nav.close()

# 5. Comparación
comprobaciones = [
    ("El puntaje en pantalla es el esperado", en_pantalla == esperado),
    ("El puntaje guardado en la base es el esperado", en_base == esperado),
    ("Hay un único resultado para el intento", filas_resultado == 1),
    ("El cambio de respuesta de la pregunta 1 quedó en interacciones (CAMBIO_OPCION)", cambios >= 1),
    ("La respuesta final de la pregunta 1 es la corregida (correcta)", final_p1 == "1"),
    ("La docente ve el mismo puntaje en el informe", en_informe == esperado),
]
linea()
linea("== 5. Comparación")
linea(f"Esperado {esperado} · pantalla {en_pantalla} · base {en_base} · informe {en_informe}")
for texto, ok in comprobaciones:
    linea(("PASS " if ok else "FAIL ") + texto)
fallas = sum(1 for _, ok in comprobaciones if not ok)
linea(f"\nResultado: {len(comprobaciones) - fallas} PASS · {fallas} FAIL")
with open(f"{SALIDA}/trazado.txt", "w", encoding="utf-8") as f:
    f.write("\n".join(informe) + "\n")
with open(f"{SALIDA}/trazado.json", "w", encoding="utf-8") as f:
    json.dump({"intento": intento_id, "esperado": esperado, "pantalla": en_pantalla, "base": en_base, "informe": en_informe,
               "resultados_guardados": filas_resultado}, f, ensure_ascii=False, indent=2)
sys.exit(1 if fallas else 0)
