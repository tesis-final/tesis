from app import features
from app.models import clustering, risk
from tests.conftest import generar_intentos


def test_kmeans_encuentra_la_estructura_y_es_reproducible(intentos_suficientes):
    v = features.construir(intentos_suficientes, "2026-09-01", "2026-09-30")
    a = clustering.agrupar(v)
    b = clustering.agrupar(v)
    assert a.presentable and a.k in (2, 3, 4)
    assert a.silueta >= clustering.SILUETA_MINIMA
    assert a.asignaciones == b.asignaciones  # determinismo
    assert set(a.asignaciones) == set(int(u) for u in v.index)


def test_kmeans_no_presenta_con_pocas_muestras():
    v = features.construir(generar_intentos(3, 5), "2026-09-01", "2026-09-30")
    r = clustering.agrupar(v)
    assert not r.presentable and "insuficientes" in r.motivo


def test_kmeans_no_presenta_sin_estructura():
    import numpy as np
    import pandas as pd
    rng = np.random.default_rng(1)
    ruido = pd.DataFrame(rng.normal(size=(60, 6)), columns=features.VARIABLES)
    r = clustering.agrupar(ruido)
    assert not r.presentable


def test_regresion_logistica_requiere_ejemplos_y_balance():
    pocos = features.ejemplos_riesgo(generar_intentos(4, 4))
    assert not risk.estimar(pocos, pocos).entrenado


def test_regresion_logistica_entrena_y_estima_probabilidades():
    datos = generar_intentos(40, 8, semilla=3)
    ejemplos = features.ejemplos_riesgo(datos)
    actuales = features.construir(datos, "2026-09-01", "2026-09-30")
    r = risk.estimar(ejemplos, actuales)
    if not r.entrenado:  # con estos datos sintéticos podría faltar balance: debe decirlo
        assert "desbalanceadas" in r.motivo or "insuficientes" in r.motivo
        return
    assert 0.0 <= r.auc <= 1.0
    assert all(0.0 <= p <= 1.0 for p in r.probabilidades.values())
    assert risk.nivel(0.8) == "alta" and risk.nivel(0.5) == "media" and risk.nivel(0.1) == "baja"


def test_regresion_logistica_camino_de_entrenamiento_con_datos_balanceados():
    """Ejemplos sintéticos balanceados donde el puntaje bajo anticipa la dificultad."""
    import numpy as np
    import pandas as pd
    rng = np.random.default_rng(11)
    n = 200
    puntaje = rng.uniform(0, 100, n)
    y = (puntaje + rng.normal(0, 12, n) < 50).astype(int)
    ejemplos = pd.DataFrame({
        "puntaje_promedio": puntaje, "tiempo_relativo": rng.uniform(0.5, 1.5, n),
        "cantidad_intentos": rng.integers(1, 10, n).astype(float), "variacion_intentos": rng.uniform(0, 20, n),
        "actividades_abandonadas": rng.integers(0, 3, n).astype(float), "frecuencia_uso": rng.uniform(0, 1, n), "y": y,
    })
    actuales = pd.DataFrame({"puntaje_promedio": [10.0, 95.0], "tiempo_relativo": [1.0, 1.0], "cantidad_intentos": [3.0, 3.0],
                             "variacion_intentos": [5.0, 5.0], "actividades_abandonadas": [0.0, 0.0], "frecuencia_uso": [0.5, 0.5]},
                            index=[101, 102])
    r = risk.estimar(ejemplos, actuales)
    assert r.entrenado
    assert r.auc > 0.8  # el modelo aprende la relación
    assert r.probabilidades[101] > r.probabilidades[102]  # puntaje bajo → mayor señal de riesgo
