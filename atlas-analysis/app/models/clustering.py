"""Agrupamiento de perfiles con K-means (PDF §25.4, RF-19; parámetros aprobados en DEC-23).

k se elige entre 2 y 4 por el mayor coeficiente de silueta. Si la mejor silueta es
menor a 0,25 no hay estructura real y NO se presentan agrupamientos.
"""

from __future__ import annotations

from dataclasses import dataclass, field

import numpy as np
import pandas as pd
from sklearn.cluster import KMeans
from sklearn.metrics import silhouette_score
from sklearn.preprocessing import StandardScaler

VERSION = "kmeans-1.0"
SILUETA_MINIMA = 0.25
K_CANDIDATOS = (2, 3, 4)
SEMILLA = 2026  # resultados reproducibles (determinismo)


@dataclass
class ResultadoAgrupamiento:
    presentable: bool
    k: int | None
    silueta: float | None
    asignaciones: dict[int, int] = field(default_factory=dict)
    motivo: str = ""


def agrupar(variables: pd.DataFrame) -> ResultadoAgrupamiento:
    """`variables`: una fila por estudiante (índice usuario_id) con las 6 variables."""
    n = len(variables)
    if n < max(K_CANDIDATOS) + 1:
        return ResultadoAgrupamiento(False, None, None, motivo=f"muestras insuficientes ({n})")
    x = StandardScaler().fit_transform(variables.to_numpy(dtype=float))
    mejor: tuple[float, int, np.ndarray] | None = None
    for k in K_CANDIDATOS:
        etiquetas = KMeans(n_clusters=k, n_init=10, random_state=SEMILLA).fit_predict(x)
        if len(set(etiquetas)) < 2:
            continue
        s = float(silhouette_score(x, etiquetas))
        if mejor is None or s > mejor[0]:
            mejor = (s, k, etiquetas)
    if mejor is None or mejor[0] < SILUETA_MINIMA:
        s = None if mejor is None else round(mejor[0], 4)
        return ResultadoAgrupamiento(False, None, s, motivo="sin estructura de agrupamiento (silueta < 0,25)")
    s, k, etiquetas = mejor
    return ResultadoAgrupamiento(
        True, k, round(s, 4), {int(u): int(e) for u, e in zip(variables.index, etiquetas)}
    )
