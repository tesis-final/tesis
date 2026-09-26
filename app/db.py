"""Acceso a datos con el usuario atlas_analysis (Tabla 21): SELECT en interacción,
INSERT en análisis. Solo identificadores numéricos y valores: nunca nombres ni correos."""

from __future__ import annotations

from contextlib import contextmanager

import pandas as pd
import pymysql

from app.config import Config

COLUMNAS = ["id", "usuario_id", "actividad_id", "estado", "puntaje", "duracion_seg", "iniciado_en"]


class Repositorio:
    def __init__(self, config: Config):
        self.config = config

    @contextmanager
    def conexion(self):
        c = pymysql.connect(
            host=self.config.db_host, port=self.config.db_port, user=self.config.db_user,
            password=self.config.db_password, database=self.config.db_name, autocommit=False,
            cursorclass=pymysql.cursors.Cursor, connect_timeout=5, charset="utf8mb4",
        )
        try:
            yield c
        finally:
            c.close()

    def ping(self) -> bool:
        with self.conexion() as c, c.cursor() as cur:
            cur.execute("SELECT 1")
            return cur.fetchone()[0] == 1

    def intentos(self, grupo: int, desde: str | None, hasta: str | None) -> pd.DataFrame:
        """Intentos cerrados de los miembros activos del grupo (período opcional)."""
        sql = (
            "SELECT i.id, i.usuario_id, i.actividad_id, i.estado, r.puntaje, i.duracion_seg, i.iniciado_en "
            "FROM intentos i LEFT JOIN resultados r ON r.intento_id = i.id "
            "WHERE i.estado <> 'EN_CURSO' AND i.usuario_id IN "
            "(SELECT usuario_id FROM usuario_grupo WHERE grupo_id = %s AND activo)"
        )
        params: list = [grupo]
        if desde and hasta:
            sql += " AND DATE(i.iniciado_en) BETWEEN %s AND %s"
            params += [desde, hasta]
        with self.conexion() as c, c.cursor() as cur:
            cur.execute(sql + " ORDER BY i.usuario_id, i.iniciado_en", params)
            filas = cur.fetchall()
        df = pd.DataFrame(filas, columns=COLUMNAS)
        if not df.empty:
            df["puntaje"] = df["puntaje"].astype(float)
            df["duracion_seg"] = df["duracion_seg"].astype(float)
        return df

    def perfiles(self, usuarios: list[int], periodo_inicio: str) -> dict[int, int]:
        if not usuarios:
            return {}
        marcas = ",".join(["%s"] * len(usuarios))
        with self.conexion() as c, c.cursor() as cur:
            cur.execute(
                f"SELECT usuario_id, id FROM perfiles_aprendizaje WHERE periodo_inicio = %s AND usuario_id IN ({marcas})",
                [periodo_inicio, *usuarios],
            )
            return {int(u): int(p) for u, p in cur.fetchall()}

    def guardar(self, grupo: int, desde: str, hasta: str, agrupamiento, riesgo, perfiles: dict[int, int], n: int) -> int | None:
        """Guarda el agrupamiento (si es presentable) y los indicadores CLUSTER/RIESGO por perfil."""
        from app.models import clustering

        agrupamiento_id = None
        with self.conexion() as c:
            try:
                with c.cursor() as cur:
                    if agrupamiento.presentable:
                        cur.execute(
                            "INSERT INTO agrupamientos (grupo_id, periodo_inicio, periodo_fin, k, silueta, n_muestras, modelo_version) "
                            "VALUES (%s, %s, %s, %s, %s, %s, %s)",
                            [grupo, desde, hasta, agrupamiento.k, agrupamiento.silueta, n, clustering.VERSION],
                        )
                        agrupamiento_id = cur.lastrowid
                        for usuario, etiqueta in agrupamiento.asignaciones.items():
                            if usuario in perfiles:
                                cur.execute(
                                    "INSERT INTO indicadores (perfil_id, agrupamiento_id, tipo, valor, origen) "
                                    "VALUES (%s, %s, 'CLUSTER', %s, 'NIVEL2')",
                                    [perfiles[usuario], agrupamiento_id, etiqueta],
                                )
                    if riesgo.entrenado:
                        for usuario, p in riesgo.probabilidades.items():
                            if usuario in perfiles:
                                cur.execute(
                                    "INSERT INTO indicadores (perfil_id, tipo, valor, origen) VALUES (%s, 'RIESGO', %s, 'NIVEL2')",
                                    [perfiles[usuario], p],
                                )
                c.commit()
            except Exception:
                c.rollback()
                raise
        return agrupamiento_id
