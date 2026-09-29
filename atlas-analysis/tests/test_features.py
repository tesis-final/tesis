import pandas as pd

from app import features
from tests.conftest import generar_intentos


def test_seis_variables_exactas_del_pdf(intentos_suficientes):
    v = features.construir(intentos_suficientes, "2026-09-01", "2026-09-30")
    assert list(v.columns) == [
        "puntaje_promedio", "tiempo_relativo", "cantidad_intentos",
        "variacion_intentos", "actividades_abandonadas", "frecuencia_uso",
    ]
    assert len(v) == 30
    assert v["frecuencia_uso"].between(0, 1).all()


def test_valores_calculados_a_mano():
    df = pd.DataFrame([
        {"usuario_id": 1, "actividad_id": 1, "estado": "FINALIZADO", "puntaje": 50.0, "duracion_seg": 100.0, "iniciado_en": "2026-09-01 10:00"},
        {"usuario_id": 1, "actividad_id": 1, "estado": "FINALIZADO", "puntaje": 100.0, "duracion_seg": 50.0, "iniciado_en": "2026-09-02 10:00"},
        {"usuario_id": 1, "actividad_id": 2, "estado": "ABANDONADO", "puntaje": None, "duracion_seg": 20.0, "iniciado_en": "2026-09-02 11:00"},
        {"usuario_id": 2, "actividad_id": 1, "estado": "FINALIZADO", "puntaje": 30.0, "duracion_seg": 150.0, "iniciado_en": "2026-09-03 10:00"},
    ])
    v = features.construir(df, "2026-09-01", "2026-09-10")
    u1 = v.loc[1]
    assert u1["puntaje_promedio"] == 75.0
    assert u1["cantidad_intentos"] == 3
    assert u1["actividades_abandonadas"] == 1
    assert u1["variacion_intentos"] == 25.0
    assert u1["frecuencia_uso"] == 0.2  # 2 días de 10
    # media del grupo en actividad 1 = (100 + 50 + 150) / 3 = 100 → relativos 1.0 y 0.5
    assert u1["tiempo_relativo"] == 0.75


def test_suficiencia_explicita():
    pocos = generar_intentos(12, 8)
    s = features.suficiencia(pocos, 20, 5)
    assert not s.suficiente and s.estudiantes_con_datos <= 12
    assert features.suficiencia(generar_intentos(30, 8), 20, 5).suficiente


def test_veinte_registros_no_alcanzan():
    # "Presentar resultados de ML sobre 20 registros sería incorrecto" (§25.4)
    veinte = generar_intentos(20, 1)
    assert not features.suficiencia(veinte, 20, 5).suficiente


def test_ejemplos_de_riesgo_rotulados():
    ej = features.ejemplos_riesgo(generar_intentos(10, 6))
    assert set(ej["y"].unique()) <= {0, 1}
    assert list(ej.columns) == features.VARIABLES + ["y"]
    assert len(ej) > 0


def test_duraciones_en_cero_no_excluyen_estudiantes():
    """Hallazgo de integración: con duraciones de 0 s el tiempo relativo es neutro (1,0)."""
    df = generar_intentos(6, 3)
    df["duracion_seg"] = 0.0
    v = features.construir(df, "2026-09-01", "2026-09-30")
    assert len(v) == 6
    assert (v["tiempo_relativo"] == 1.0).all()
