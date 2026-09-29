"""Detección de riesgo con regresión logística (PDF §25.4; DEC-23).

Es supervisada: se entrena con ejemplos rotulados a partir de la propia historia
(features.ejemplos_riesgo). Solo se entrena con ≥ 100 ejemplos y cada clase ≥ 20 %;
se valida con 5 particiones y se informa el AUC. El resultado es una SEÑAL
estadística, nunca un diagnóstico (§18).
"""

from __future__ import annotations

from dataclasses import dataclass, field

import numpy as np
import pandas as pd
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import StratifiedKFold, cross_val_score
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler

from app.features import VARIABLES

VERSION = "logreg-1.0"
MINIMO_EJEMPLOS = 100
PROPORCION_MINIMA_CLASE = 0.20


@dataclass
class ResultadoRiesgo:
    entrenado: bool
    motivo: str = ""
    auc: float | None = None
    probabilidades: dict[int, float] = field(default_factory=dict)


def estimar(ejemplos: pd.DataFrame, actuales: pd.DataFrame) -> ResultadoRiesgo:
    """Entrena con `ejemplos` (6 variables + y) y estima la probabilidad para `actuales`."""
    n = len(ejemplos)
    if n < MINIMO_EJEMPLOS:
        return ResultadoRiesgo(False, f"ejemplos insuficientes ({n} de {MINIMO_EJEMPLOS})")
    proporcion = float(ejemplos["y"].mean())
    if min(proporcion, 1 - proporcion) < PROPORCION_MINIMA_CLASE:
        return ResultadoRiesgo(False, f"clases desbalanceadas ({proporcion:.0%} positivos)")
    x = ejemplos[VARIABLES].to_numpy(dtype=float)
    y = ejemplos["y"].to_numpy(dtype=int)
    modelo = make_pipeline(StandardScaler(), LogisticRegression(max_iter=1000, random_state=2026))
    auc = float(np.mean(cross_val_score(modelo, x, y, cv=StratifiedKFold(5, shuffle=True, random_state=2026), scoring="roc_auc")))
    modelo.fit(x, y)
    if actuales.empty:
        return ResultadoRiesgo(True, auc=round(auc, 4))
    p = modelo.predict_proba(actuales[VARIABLES].to_numpy(dtype=float))[:, 1]
    return ResultadoRiesgo(True, auc=round(auc, 4), probabilidades={int(u): round(float(v), 4) for u, v in zip(actuales.index, p)})


def nivel(probabilidad: float) -> str:
    """Lectura para el docente: alta / media / baja (etiqueta de la señal, no de la persona)."""
    return "alta" if probabilidad >= 0.66 else "media" if probabilidad >= 0.33 else "baja"
