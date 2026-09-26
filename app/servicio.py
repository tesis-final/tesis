"""Orquestación del Nivel 2: suficiencia → variables → K-means → regresión logística → guardado."""

from __future__ import annotations

from datetime import date, timedelta

from app import features
from app.config import Config
from app.db import Repositorio
from app.models import clustering, risk


def estado(repo: Repositorio, config: Config, grupo: int, desde: str, hasta: str) -> dict:
    intentos = repo.intentos(grupo, desde, hasta)
    s = features.suficiencia(intentos, config.ml_min_estudiantes, config.ml_min_intentos)
    return {"grupo_id": grupo, "periodo": [desde, hasta], "suficiencia": s.como_dict()}


def recalcular(repo: Repositorio, config: Config, grupo: int, desde: str, hasta: str) -> dict:
    intentos = repo.intentos(grupo, desde, hasta)
    s = features.suficiencia(intentos, config.ml_min_estudiantes, config.ml_min_intentos)
    if not s.suficiente:
        # Condición explícita: no se presentan resultados de ML con pocos datos (§25.4).
        return {"estado": "datos_insuficientes", "suficiencia": s.como_dict()}

    variables = features.construir(intentos, desde, hasta)
    agrupamiento = clustering.agrupar(variables)

    historia_desde = (date.fromisoformat(hasta) - timedelta(days=180)).isoformat()
    ejemplos = features.ejemplos_riesgo(repo.intentos(grupo, historia_desde, hasta))
    riesgo = risk.estimar(ejemplos, variables)

    perfiles = repo.perfiles([int(u) for u in variables.index], desde)
    agrupamiento_id = repo.guardar(grupo, desde, hasta, agrupamiento, riesgo, perfiles, len(variables))
    return {
        "estado": "ok",
        "suficiencia": s.como_dict(),
        "agrupamiento": {
            "presentable": agrupamiento.presentable, "id": agrupamiento_id, "k": agrupamiento.k,
            "silueta": agrupamiento.silueta, "motivo": agrupamiento.motivo, "version": clustering.VERSION,
        },
        "riesgo": {"entrenado": riesgo.entrenado, "motivo": riesgo.motivo, "auc": riesgo.auc,
                   "estimaciones": len(riesgo.probabilidades), "version": risk.VERSION},
    }
