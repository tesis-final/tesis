"""Datos SINTÉTICOS para probar el código (nunca se reportan como resultados reales, R-10)."""

import numpy as np
import pandas as pd
import pytest


def generar_intentos(n_estudiantes: int, intentos_por_estudiante: int, semilla: int = 7, perfiles: int = 3) -> pd.DataFrame:
    """Estudiantes de `perfiles` tipos bien diferenciados (rápidos-altos, lentos-medios, abandonan)."""
    rng = np.random.default_rng(semilla)
    filas, i = [], 0
    for u in range(1, n_estudiantes + 1):
        tipo = u % perfiles
        base = pd.Timestamp("2026-09-01")
        for k in range(intentos_por_estudiante):
            i += 1
            abandona = tipo == 2 and rng.random() < 0.4
            puntaje = {0: 90, 1: 60, 2: 35}[tipo] + rng.normal(0, 5)
            duracion = {0: 60, 1: 150, 2: 100}[tipo] + rng.normal(0, 10)
            filas.append({
                "id": i, "usuario_id": u, "actividad_id": (k % 4) + 1,
                "estado": "ABANDONADO" if abandona else "FINALIZADO",
                "puntaje": None if abandona else float(np.clip(puntaje, 0, 100)),
                "duracion_seg": float(max(5, duracion)),
                "iniciado_en": base + pd.Timedelta(days=int(k * (1 if tipo == 0 else 3)), hours=int(u % 5)),
            })
    return pd.DataFrame(filas)


@pytest.fixture
def intentos_suficientes():
    return generar_intentos(30, 8)
