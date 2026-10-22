"""ATLAS — prueba de interfaz en navegador real (Playwright + Chromium).

Verifica RNF-12 (escritorio, tableta, celular sin desplazamiento horizontal),
la ausencia de errores de consola/CSP y los recorridos principales por rol.
Uso: python interfaz.py <url_base> <dir_capturas> <clave_demo>
Los datos que se ven son de DEMOSTRACIÓN (sintéticos).
"""

import json
import os
import sys

from playwright.sync_api import sync_playwright

BASE, CAPTURAS, CLAVE = sys.argv[1], sys.argv[2], sys.argv[3]
ANCHOS = {"celular-375": 375, "corte-480": 480, "tableta-768": 768, "escritorio-1024": 1024, "escritorio-1366": 1366}
resultados = []


def registrar(prueba, ok, detalle=""):
    resultados.append({"prueba": prueba, "resultado": "PASS" if ok else "FAIL", "detalle": detalle})
    print(("PASS " if ok else "FAIL ") + prueba + (f" — {detalle}" if detalle else ""))


def sin_scroll_horizontal(page):
    return page.evaluate("document.documentElement.scrollWidth <= window.innerWidth + 1")


def entrar(page, correo):
    page.goto(BASE + "/#/login")
    page.fill("#correo", correo)
    page.fill("#contrasena", CLAVE)
    page.click("button[type=submit]")
    page.wait_for_selector("#sesion button")


with sync_playwright() as p:
    # PW_CHROMIUM: Chromium propio; si no se indica, el que trae Playwright (p. ej. su imagen Docker).
    nav = p.chromium.launch(executable_path=os.environ.get("PW_CHROMIUM") or None, args=["--no-sandbox"])
    ctx = nav.new_context(ignore_https_errors=True, locale="es-UY")
    page = ctx.new_page()
    errores = []
    page.on("console", lambda m: errores.append(m.text) if m.type == "error" else None)
    page.on("pageerror", lambda e: errores.append(str(e)))

    # RF-02: error genérico
    page.goto(BASE + "/#/login")
    page.fill("#correo", "docente.demo@atlas.local")
    page.fill("#contrasena", "incorrecta-000")
    page.click("button[type=submit]")
    page.wait_for_selector(".mensaje.error")
    registrar("RF-02 mensaje genérico en la interfaz", "Correo o contraseña incorrectos." in page.inner_text(".mensajes"))

    # Docente: dónde intervenir, en todos los anchos
    entrar(page, "docente.demo@atlas.local")
    page.wait_for_selector("text=Dónde intervenir hoy")
    page.wait_for_selector("text=Atención prioritaria")
    for nombre, ancho in ANCHOS.items():
        page.set_viewport_size({"width": ancho, "height": 900})
        page.wait_for_timeout(250)
        page.screenshot(path=f"{CAPTURAS}/docente-donde-intervenir-{nombre}.png", full_page=True)
        registrar(f"RNF-12 sin desplazamiento horizontal · docente inicio · {ancho}px", sin_scroll_horizontal(page))

    page.set_viewport_size({"width": 1366, "height": 900})
    page.goto(BASE + "/#/grupo/1")
    page.wait_for_selector("text=Distribución de puntajes")
    page.screenshot(path=f"{CAPTURAS}/docente-analisis-grupal-1366.png", full_page=True)
    registrar("RF-18 análisis grupal visible", page.locator("text=Preguntas con mayor proporción de error").count() > 0)
    page.set_viewport_size({"width": 375, "height": 900})
    page.wait_for_timeout(250)
    page.screenshot(path=f"{CAPTURAS}/docente-analisis-grupal-375.png", full_page=True)
    registrar("RNF-12 tablas como tarjetas en celular (sin desplazamiento horizontal)", sin_scroll_horizontal(page))

    # Perfil + ¿por qué?
    page.set_viewport_size({"width": 1024, "height": 900})
    page.goto(BASE + "/#/grupo/1")
    page.wait_for_selector("text=Atención prioritaria")
    enlace = page.locator("section:has-text('Atención prioritaria') a").first
    enlace.click()
    page.wait_for_selector("text=Perfil de aprendizaje")
    page.locator("button:has-text('¿Por qué?')").first.click()
    page.wait_for_selector("text=Fundamento de la recomendación")
    page.screenshot(path=f"{CAPTURAS}/docente-por-que-1024.png", full_page=True)
    registrar("RF-12 '¿por qué?' muestra regla, versión y datos", page.locator("text=Datos usados:").count() > 0)
    registrar("D-3 el perfil muestra el acierto por habilidad", page.locator("text=Acierto por habilidad").count() > 0)

    # D-6: el sistema recomienda y el docente decide. Se elige un estudiante del grupo con una
    # recomendación pendiente que sugiera una actividad; después se entra como ese estudiante.
    elegido = page.evaluate("""async () => {
        const miembros = await (await fetch('/api/v1/grupos/1/miembros')).json();
        for (const e of miembros.filter((m) => m.rol === 'ESTUDIANTE')) {
            const p = await (await fetch(`/api/v1/docente/estudiantes/${e.id}/perfil`)).json();
            if (p.recomendaciones.some((r) => !r.decision && r.actividad_sugerida_id)) return { id: e.id, nombre: e.nombre };
        }
        return null;
    }""")
    estudiante_d6 = "ana.demo@atlas.local"
    if elegido:
        nombre = elegido["nombre"].lower()
        for a, b in (("á", "a"), ("é", "e"), ("í", "i"), ("ó", "o"), ("ú", "u")):
            nombre = nombre.replace(a, b)
        estudiante_d6 = f"{nombre}.demo@atlas.local"
        # Se espera a que termine de cargar el perfil de ESTE estudiante: hasta entonces se
        # sigue viendo el perfil anterior y el clic quedaría en otro estudiante.
        with page.expect_response(lambda r: f"/docente/estudiantes/{elegido['id']}/perfil" in r.url):
            page.goto(BASE + f"/#/estudiante/{elegido['id']}")
        page.wait_for_load_state("networkidle")
        page.locator("button:has-text('Confirmar «')").first.click()
        page.wait_for_selector("text=Confirmada por usted")
        page.screenshot(path=f"{CAPTURAS}/docente-decision-recomendacion-1024.png", full_page=True)
    registrar("D-6 el docente confirma la actividad sugerida", page.locator("text=Confirmada por usted").count() > 0,
              "" if elegido else "ningún estudiante con una recomendación que sugiera actividad")

    # D-5: consultas guiadas (grupo + período + qué ver)
    page.goto(BASE + "/#/consultas")
    page.wait_for_selector("text=3. ¿Qué quiere ver?")
    page.check("input[name=que][value=habilidades]")
    page.click("button:has-text('Consultar')")
    page.wait_for_selector("section:has-text('Acierto por habilidad') table, section:has-text('Acierto por habilidad') .vacio")
    page.screenshot(path=f"{CAPTURAS}/docente-consultas-habilidades-1024.png", full_page=True)
    registrar("D-5 consulta guiada por habilidad responde",
              page.locator("h1:has-text('Consultas')").count() == 1
              and page.locator("section:has-text('Acierto por habilidad') table").count() > 0)
    page.check("input[name=que][value=atencion]")
    page.click("button:has-text('Consultar')")
    page.wait_for_selector("text=Motivo (reglas)")
    page.set_viewport_size({"width": 375, "height": 900})
    page.wait_for_timeout(250)
    page.screenshot(path=f"{CAPTURAS}/docente-consultas-atencion-375.png", full_page=True)
    registrar("RNF-12 consultas en celular sin desplazamiento horizontal", sin_scroll_horizontal(page))
    page.set_viewport_size({"width": 1024, "height": 900})

    # D-3 + D-2: crear una actividad con habilidades y publicarla directo (sin aprobación)
    page.goto(BASE + "/#/actividades/nueva")
    page.wait_for_selector("text=Habilidades que mide")
    page.fill("#titulo", "Actividad creada en la prueba de interfaz")
    bloque = page.locator(".pregunta").first
    bloque.locator("textarea.enunciado").fill("¿Cuánto es 3 × 4?")
    textos = bloque.locator(".texto-opcion")
    textos.nth(0).fill("12")
    textos.nth(1).fill("7")
    bloque.locator("input[type=radio]").first.check()
    bloque.locator(".habilidades input[value=CALCULO]").check()
    page.screenshot(path=f"{CAPTURAS}/docente-editor-habilidades-1024.png", full_page=True)
    page.click("button:has-text('Guardar borrador')")
    page.wait_for_selector("text=Publicar en:")
    registrar("D-2 sin aprobación el borrador ofrece Publicar (no 'Enviar a aprobación')",
              page.locator("button:has-text('Enviar a aprobación')").count() == 0)
    page.locator("input[name=grupo]").first.check()
    page.click("button:has-text('Publicar')")
    page.wait_for_selector(".etiqueta.estado:has-text('Publicada')")
    registrar("D-2/D-3 actividad con habilidades publicada desde la interfaz", True)

    # D-8: tiempo activo en los reportes
    page.goto(BASE + "/#/reportes")
    page.wait_for_selector("text=Tiempo medio activo")
    page.screenshot(path=f"{CAPTURAS}/docente-reportes-1024.png", full_page=True)
    registrar("D-8 los reportes muestran tiempo total y activo", page.locator("th:has-text('Tiempo activo')").count() > 0)

    # Asistente (sin clave de Groq en esta prueba → datos verificados, RNF-15)
    page.goto(BASE + "/#/asistente")
    page.fill("#pregunta", "¿Cómo viene el grupo 3A en resolución de problemas?")
    page.click("button:has-text('Preguntar')")
    page.wait_for_selector(".burbuja.atlas")
    page.screenshot(path=f"{CAPTURAS}/docente-asistente-1024.png", full_page=True)
    registrar("RF-20 / RNF-15 el asistente responde con datos verificados sin LLM", "datos verificados" in page.inner_text("#app"))
    page.click("#sesion button")
    page.wait_for_selector("#correo")  # el logout recarga la página y vuelve al login

    # Estudiante: resolver una actividad por la interfaz
    page.set_viewport_size({"width": 375, "height": 800})
    entrar(page, estudiante_d6)
    page.wait_for_selector("h1:has-text('Mis actividades')")  # el menú también dice "Mis actividades"
    page.screenshot(path=f"{CAPTURAS}/estudiante-actividades-375.png", full_page=True)
    registrar("D-6 el estudiante ve la actividad recomendada por su docente",
              page.locator("text=Recomendada por tu docente").count() > 0)
    page.locator("a.boton").first.click()
    page.wait_for_selector(".pregunta")
    for i in range(4):
        page.locator(".opcion input").first.check()
        page.wait_for_timeout(150)
        if page.locator("button:has-text('Siguiente')").count():
            page.click("button:has-text('Siguiente')")
            page.wait_for_selector(f"text=Pregunta {i + 2} de")
    page.screenshot(path=f"{CAPTURAS}/estudiante-resolviendo-375.png", full_page=True)
    registrar("RNF-12 resolución en celular sin desplazamiento horizontal", sin_scroll_horizontal(page))
    page.click("button:has-text('Finalizar')")
    page.wait_for_selector("text=Resultado")
    page.screenshot(path=f"{CAPTURAS}/estudiante-resultado-375.png", full_page=True)
    registrar("RF-07 el estudiante ve su resultado", "Puntaje" in page.inner_text("#app"))
    registrar("D-8 el resultado muestra tiempo total y activo", "Tiempo activo" in page.inner_text("#app"))
    registrar("DEC-00b el estudiante no ve menú docente", page.locator("#menu a").count() == 1)
    page.click("#sesion button")
    page.wait_for_selector("#correo")  # el logout recarga la página y vuelve al login

    # Administrador
    page.set_viewport_size({"width": 768, "height": 900})
    entrar(page, "coordinacion.demo@atlas.local")
    page.wait_for_selector("text=Actividades a revisar")
    page.goto(BASE + "/#/reglas")
    page.wait_for_selector("text=R08")
    page.screenshot(path=f"{CAPTURAS}/admin-reglas-768.png", full_page=True)
    registrar("ANA-05 reglas editables visibles para la coordinación", page.locator("section.tarjeta").count() == 8)
    page.goto(BASE + "/#/auditoria")
    page.wait_for_selector("table.tabla, .vacio")
    page.screenshot(path=f"{CAPTURAS}/admin-auditoria-768.png", full_page=True)
    registrar("RF-15 auditoría consultable", page.locator("table.tabla tbody tr").count() > 0)
    page.goto(BASE + "/#/instituciones")
    page.wait_for_selector("text=Aprobación previa")
    page.screenshot(path=f"{CAPTURAS}/admin-instituciones-768.png", full_page=True)
    registrar("D-2 la coordinación ve y configura la aprobación por institución",
              page.locator("td:has-text('No exige')").count() > 0)

    csp = [e for e in errores if "Content Security Policy" in e or "Refused" in e]
    registrar("Sin violaciones de CSP", not csp, "; ".join(csp[:3]))
    otros = [e for e in errores if e not in csp and "401" not in e and "Failed to load resource" not in e]
    registrar("Sin errores de JavaScript", not otros, "; ".join(otros[:3]))
    nav.close()

with open(f"{CAPTURAS}/resultado-interfaz.json", "w", encoding="utf-8") as f:
    json.dump(resultados, f, ensure_ascii=False, indent=2)
fallos = [r for r in resultados if r["resultado"] == "FAIL"]
print(f"\n{len(resultados) - len(fallos)}/{len(resultados)} PASS")
sys.exit(1 if fallos else 0)
