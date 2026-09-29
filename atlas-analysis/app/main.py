"""ATLAS — API REST interna del servicio de análisis (PDF §25.2, §26.2).

Solo es alcanzable desde la red interna de contenedores (atlas_back); no se publica.
Si este servicio cae, ATLAS sigue registrando y el Nivel 1 sigue funcionando (RNF-15).
"""

from __future__ import annotations

import logging
from datetime import date

from fastapi import Depends, FastAPI, HTTPException, Query
from pydantic import BaseModel, Field, field_validator

from app import servicio
from app.config import Config
from app.db import Repositorio
from app.llm.client import ClienteLLM, LLMNoDisponible

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s atlas-analysis %(message)s")
log = logging.getLogger("atlas-analysis")

app = FastAPI(title="ATLAS — servicio de análisis", version="1.0", docs_url=None, redoc_url=None)


def obtener_config() -> Config:
    return Config.desde_entorno()


def obtener_repo(config: Config = Depends(obtener_config)) -> Repositorio:
    return Repositorio(config)


def obtener_llm(config: Config = Depends(obtener_config)) -> ClienteLLM:
    return ClienteLLM(config)


class Periodo(BaseModel):
    desde: date
    hasta: date

    @field_validator("hasta")
    @classmethod
    def orden(cls, v: date, info):
        if "desde" in info.data and v < info.data["desde"]:
            raise ValueError("hasta debe ser posterior a desde")
        return v


class PedidoRedaccion(BaseModel):
    tipo: str = Field(pattern="^(ESTADO_GRUPO|DIFICULTAD|EXPLICAR_RECOMENDACION)$")
    pregunta: str = Field(max_length=1000)
    contexto: dict


@app.get("/health")
def salud(repo: Repositorio = Depends(obtener_repo)):
    try:
        bd = repo.ping()
    except Exception:  # noqa: BLE001 — la salud informa, no falla
        bd = False
    return {"estado": "ok" if bd else "degradado", "base_de_datos": bd}


@app.get("/v1/grupos/{grupo}/estado")
def estado(grupo: int, desde: date = Query(), hasta: date = Query(),
           repo: Repositorio = Depends(obtener_repo), config: Config = Depends(obtener_config)):
    return servicio.estado(repo, config, grupo, desde.isoformat(), hasta.isoformat())


@app.post("/v1/grupos/{grupo}/recalcular")
def recalcular(grupo: int, periodo: Periodo,
               repo: Repositorio = Depends(obtener_repo), config: Config = Depends(obtener_config)):
    resultado = servicio.recalcular(repo, config, grupo, periodo.desde.isoformat(), periodo.hasta.isoformat())
    log.info("recalcular grupo=%s estado=%s", grupo, resultado["estado"])
    return resultado


@app.post("/v1/llm/redactar")
def redactar(pedido: PedidoRedaccion, llm: ClienteLLM = Depends(obtener_llm)):
    try:
        return llm.redactar(pedido.tipo, pedido.pregunta, pedido.contexto)
    except LLMNoDisponible as e:
        log.warning("LLM no disponible: %s", e)
        raise HTTPException(status_code=503, detail="Modelo de lenguaje no disponible") from e
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e)) from e
