import json

import httpx
import pytest
from fastapi.testclient import TestClient

from app import main
from app.config import Config
from app.llm.client import ClienteLLM, LLMNoDisponible


def config(clave="clave-de-prueba") -> Config:
    return Config("h", 3306, "atlas_db", "atlas_analysis", "x", "groq", "https://api.groq.com/openai/v1",
                  clave, "llama-3.3-70b-versatile", 5, 20, 5)


CONTEXTO = {"estudiante": "E1", "reglas_que_la_generaron": [{"codigo": "R01", "valores": {"puntaje": 25.0}}]}


def test_envia_a_groq_formato_openai_y_solo_seudonimos():
    capturado = {}

    def responder(request: httpx.Request):
        capturado["url"] = str(request.url)
        capturado["auth"] = request.headers["authorization"]
        capturado["cuerpo"] = json.loads(request.content)
        return httpx.Response(200, json={"model": "llama-3.3-70b-versatile",
                                         "choices": [{"message": {"content": "E1 obtuvo 25 puntos; se cumplió R01."}}]})

    r = ClienteLLM(config(), httpx.MockTransport(responder)).redactar("EXPLICAR_RECOMENDACION", "¿Por qué para E1?", CONTEXTO)
    assert r["texto"] == "E1 obtuvo 25 puntos; se cumplió R01."
    assert capturado["url"] == "https://api.groq.com/openai/v1/chat/completions"
    assert capturado["auth"] == "Bearer clave-de-prueba"
    assert capturado["cuerpo"]["model"] == "llama-3.3-70b-versatile"
    sistema = capturado["cuerpo"]["messages"][0]["content"]
    assert "No inventes" in sistema and "No diagnostiques" in sistema
    assert "E1" in capturado["cuerpo"]["messages"][1]["content"]


def test_no_envia_si_hay_un_correo():
    def no_debe_llamarse(request):
        raise AssertionError("no debía enviarse")

    with pytest.raises(ValueError):
        ClienteLLM(config(), httpx.MockTransport(no_debe_llamarse)).redactar(
            "DIFICULTAD", "x", {"dato": "ana@iti.edu.uy"})


@pytest.mark.parametrize("cedula", ["4.567.890-1", "45678901", "1.234.567-8"])
def test_no_envia_si_hay_una_cedula(cedula):
    def no_debe_llamarse(request):
        raise AssertionError("no debía enviarse")

    with pytest.raises(ValueError):
        ClienteLLM(config(), httpx.MockTransport(no_debe_llamarse)).redactar(
            "DIFICULTAD", "x", {"dato": f"CI {cedula}"})


def test_fechas_y_valores_no_se_confunden_con_cedulas():
    capturado = {}

    def responder(request):
        capturado["ok"] = True
        return httpx.Response(200, json={"choices": [{"message": {"content": "texto"}}]})

    ClienteLLM(config(), httpx.MockTransport(responder)).redactar(
        "DIFICULTAD", "x", {"periodo": "2026-09-01/2026-09-30", "silueta": 0.2946, "promedio": 71.25, "n": 1250})
    assert capturado.get("ok")


def test_sin_clave_o_con_error_es_no_disponible():
    with pytest.raises(LLMNoDisponible):
        ClienteLLM(config(clave="")).redactar("DIFICULTAD", "x", {})
    with pytest.raises(LLMNoDisponible):
        ClienteLLM(config(), httpx.MockTransport(lambda r: httpx.Response(500))).redactar("DIFICULTAD", "x", {})


class RepoFalso:
    def __init__(self, df):
        self.df = df
        self.guardado = None

    def ping(self):
        return True

    def intentos(self, grupo, desde, hasta):
        return self.df

    def perfiles(self, usuarios, periodo):
        return {u: 1000 + u for u in usuarios}

    def guardar(self, grupo, desde, hasta, agrupamiento, riesgo, perfiles, n):
        self.guardado = (agrupamiento, riesgo, n)
        return 77


def cliente_api(df, llm=None):
    repo = RepoFalso(df)
    main.app.dependency_overrides[main.obtener_repo] = lambda: repo
    main.app.dependency_overrides[main.obtener_config] = lambda: config()
    if llm is not None:
        main.app.dependency_overrides[main.obtener_llm] = lambda: llm
    return TestClient(main.app), repo


def test_api_estado_y_recalculo_con_datos_insuficientes():
    from tests.conftest import generar_intentos
    c, repo = cliente_api(generar_intentos(10, 8))
    r = c.get("/v1/grupos/1/estado", params={"desde": "2026-09-01", "hasta": "2026-09-30"})
    assert r.status_code == 200 and r.json()["suficiencia"]["suficiente"] is False
    r = c.post("/v1/grupos/1/recalcular", json={"desde": "2026-09-01", "hasta": "2026-09-30"})
    assert r.json()["estado"] == "datos_insuficientes"
    assert repo.guardado is None  # no se guarda nada con pocos datos


def test_api_recalculo_con_datos_suficientes():
    from tests.conftest import generar_intentos
    c, repo = cliente_api(generar_intentos(30, 8))
    r = c.post("/v1/grupos/1/recalcular", json={"desde": "2026-09-01", "hasta": "2026-09-30"})
    cuerpo = r.json()
    assert cuerpo["estado"] == "ok"
    assert cuerpo["agrupamiento"]["presentable"] is True
    assert repo.guardado[2] == 30


def test_api_redactar_503_si_no_hay_modelo():
    c, _ = cliente_api(None, ClienteLLM(config(clave="")))
    r = c.post("/v1/llm/redactar", json={"tipo": "DIFICULTAD", "pregunta": "x", "contexto": {}})
    assert r.status_code == 503


def test_api_rechaza_tipos_desconocidos():
    c, _ = cliente_api(None)
    r = c.post("/v1/llm/redactar", json={"tipo": "CUALQUIERA", "pregunta": "x", "contexto": {}})
    assert r.status_code == 422
