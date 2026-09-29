"""ATLAS — prueba de interfaz en navegador real (Playwright + Chromium).

Verifica RNF-12 (escritorio, tableta, celular sin desplazamiento horizontal),
la ausencia de errores de consola/CSP y los recorridos principales por rol.
Uso: python interfaz.py <url_base> <dir_capturas> <clave_demo>
Los datos que se ven son de DEMOSTRACIÓN (sintéticos).
"""

import json
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
    nav = p.chromium.launch(executable_path="/opt/pw-browsers/chromium-1194/chrome-linux/chrome", args=["--no-sandbox"])
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

    # Asistente (sin clave de Groq en esta prueba → datos verificados, RNF-15)
    page.goto(BASE + "/#/asistente")
    page.fill("#pregunta", "¿Cómo viene el grupo 3A en resolución de problemas?")
    page.click("button:has-text('Preguntar')")
    page.wait_for_selector(".burbuja.atlas")
    page.screenshot(path=f"{CAPTURAS}/docente-asistente-1024.png", full_page=True)
    registrar("RF-20 / RNF-15 el asistente responde con datos verificados sin LLM", "datos verificados" in page.inner_text("#app"))
    page.click("#sesion button")

    # Estudiante: resolver una actividad por la interfaz
    page.set_viewport_size({"width": 375, "height": 800})
    entrar(page, "ana.demo@atlas.local")
    page.wait_for_selector("text=Mis actividades")
    page.screenshot(path=f"{CAPTURAS}/estudiante-actividades-375.png", full_page=True)
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
    registrar("DEC-00b el estudiante no ve menú docente", page.locator("#menu a").count() == 1)
    page.click("#sesion button")

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
