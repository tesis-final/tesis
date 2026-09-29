"""Preparación de las seis variables de los modelos (PDF §25.4; DEC-23).

Entrada: intentos de los estudiantes de un grupo en un período (solo identificadores
numéricos y valores; el servicio nunca lee nombres ni correos).
"""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np
import pandas as pd

VARIABLES = [
    "puntaje_promedio",
    "tiempo_relativo",
    "cantidad_intentos",
    "variacion_intentos",
    "actividades_abandonadas",
    "frecuencia_uso",
]


@dataclass(frozen=True)
class Suficiencia:
    """Condición explícita para ejecutar los modelos (el PDF: ML sobre 20 registros sería incorrecto)."""

    suficiente: bool
    estudiantes_con_datos: int
    requeridos: int
    intentos_minimos: int

    def como_dict(self) -> dict:
        return {
            "suficiente": self.suficiente,
            "estudiantes_con_datos": self.estudiantes_con_datos,
            "requeridos": self.requeridos,
            "intentos_minimos": self.intentos_minimos,
        }


def suficiencia(intentos: pd.DataFrame, min_estudiantes: int, min_intentos: int) -> Suficiencia:
    """Estudiantes con al menos `min_intentos` intentos finalizados; hacen falta `min_estudiantes`."""
    if intentos.empty:
        return Suficiencia(False, 0, min_estudiantes, min_intentos)
    finalizados = intentos[intentos["estado"] == "FINALIZADO"].groupby("usuario_id").size()
    con_datos = int((finalizados >= min_intentos).sum())
    return Suficiencia(con_datos >= min_estudiantes, con_datos, min_estudiantes, min_intentos)


def construir(intentos: pd.DataFrame, desde: str, hasta: str) -> pd.DataFrame:
    """Una fila por estudiante con las 6 variables.

    Columnas esperadas en `intentos`: usuario_id, actividad_id, estado, puntaje,
    duracion_seg, iniciado_en.
    """
    if intentos.empty:
        return pd.DataFrame(columns=VARIABLES)
    df = intentos.copy()
    df["iniciado_en"] = pd.to_datetime(df["iniciado_en"])
    fin = df[df["estado"] == "FINALIZADO"].copy()

    # Tiempo relativo al grupo: duración propia / media del grupo en la misma actividad.
    media_actividad = fin.groupby("actividad_id")["duracion_seg"].transform("mean")
    fin["relativo"] = np.where(media_actividad > 0, fin["duracion_seg"] / media_actividad, np.nan)

    dias_periodo = max(1, (pd.Timestamp(hasta) - pd.Timestamp(desde)).days + 1)
    por_estudiante = df.groupby("usuario_id")
    salida = pd.DataFrame(index=sorted(df["usuario_id"].unique()))
    salida["puntaje_promedio"] = fin.groupby("usuario_id")["puntaje"].mean()
    salida["tiempo_relativo"] = fin.groupby("usuario_id")["relativo"].mean()
    salida["cantidad_intentos"] = por_estudiante.size()
    salida["variacion_intentos"] = fin.groupby("usuario_id")["puntaje"].std(ddof=0)
    salida["actividades_abandonadas"] = df[df["estado"] == "ABANDONADO"].groupby("usuario_id").size()
    salida["frecuencia_uso"] = por_estudiante["iniciado_en"].apply(lambda s: s.dt.date.nunique()) / dias_periodo

    salida["cantidad_intentos"] = salida["cantidad_intentos"].fillna(0)
    salida["actividades_abandonadas"] = salida["actividades_abandonadas"].fillna(0)
    salida["variacion_intentos"] = salida["variacion_intentos"].fillna(0.0)
    # Si la media del grupo es 0 o no existe, el tiempo relativo es neutro (1,0) en lugar de
    # excluir al estudiante (hallazgo de integración: duraciones de 0 s).
    salida["tiempo_relativo"] = salida["tiempo_relativo"].fillna(1.0)
    # Sin intentos finalizados no hay puntaje: esos estudiantes no entran al modelo.
    salida = salida.dropna(subset=["puntaje_promedio"])
    salida.index.name = "usuario_id"
    return salida[VARIABLES].astype(float)


def ejemplos_riesgo(intentos: pd.DataFrame, caida: float = 15.0) -> pd.DataFrame:
    """Ejemplos rotulados para la regresión logística (etiqueta aprobada en DEC-23).

    Para cada intento finalizado k de un estudiante (salvo el último), las variables se
    calculan con su historia hasta k y la etiqueta y = 1 si en la **siguiente** actividad
    el puntaje cae ≥ `caida` puntos respecto de su promedio previo, o si la abandona.
    """
    filas = []
    if intentos.empty:
        return pd.DataFrame(columns=VARIABLES + ["y"])
    df = intentos.copy()
    df["iniciado_en"] = pd.to_datetime(df["iniciado_en"])
    df = df.sort_values(["usuario_id", "iniciado_en"])
    medias_actividad = df[df["estado"] == "FINALIZADO"].groupby("actividad_id")["duracion_seg"].mean()
    for usuario, hist in df.groupby("usuario_id"):
        hist = hist.reset_index(drop=True)
        for k in range(len(hist) - 1):
            previo = hist.iloc[: k + 1]
            siguiente = hist.iloc[k + 1]
            fin = previo[previo["estado"] == "FINALIZADO"]
            if fin.empty:
                continue
            promedio = fin["puntaje"].mean()
            relativos = fin["duracion_seg"] / fin["actividad_id"].map(medias_actividad)
            dias = max(1, (previo["iniciado_en"].max() - previo["iniciado_en"].min()).days + 1)
            y = int(siguiente["estado"] == "ABANDONADO"
                    or (siguiente["estado"] == "FINALIZADO" and siguiente["puntaje"] <= promedio - caida))
            filas.append({
                "puntaje_promedio": promedio,
                "tiempo_relativo": float(relativos.replace([np.inf, -np.inf], np.nan).mean() or 1.0),
                "cantidad_intentos": float(len(previo)),
                "variacion_intentos": float(fin["puntaje"].std(ddof=0) if len(fin) > 1 else 0.0),
                "actividades_abandonadas": float((previo["estado"] == "ABANDONADO").sum()),
                "frecuencia_uso": previo["iniciado_en"].dt.date.nunique() / dias,
                "y": y,
            })
    return pd.DataFrame(filas, columns=VARIABLES + ["y"])
