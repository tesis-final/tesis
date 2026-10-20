#!/usr/bin/env python3
"""Genera el DER (Mermaid) y el diccionario de datos desde una base atlas_db en
ejecución (information_schema), para que la documentación coincida con el
script real. Uso: generar_documentacion.py <contenedor> <root_password> <dir_salida>
"""
import subprocess
import sys
from collections import defaultdict

cont, pwd, salida = sys.argv[1:4]


def q(sql):
    out = subprocess.run(
        ["docker", "exec", cont, "mysql", "-uroot", f"-p{pwd}", "-N", "-B", "-e", sql],
        capture_output=True, text=True, check=True).stdout
    return [line.split("\t") for line in out.strip().split("\n") if line]


GRUPOS = {
    "Identidad": ["instituciones", "roles", "permisos", "rol_permiso", "usuarios", "grupos_clase", "usuario_grupo"],
    "Contenido": ["niveles_dificultad", "categorias", "estados_actividad", "actividades", "preguntas", "opciones",
                  "transiciones_actividad", "actividad_grupo", "habilidades", "pregunta_habilidad"],
    "Interacción": ["intentos", "respuestas", "interacciones", "resultados"],
    "Análisis": ["perfiles_aprendizaje", "indicadores", "reglas_analisis", "recomendaciones",
                 "recomendacion_regla", "analisis_grupal", "agrupamientos"],
    "Control": ["auditoria", "conversaciones", "registro_respaldos"],
}

cols = q("""SELECT table_name, column_name, column_type, is_nullable, column_key,
                   IFNULL(column_default,''), extra
              FROM information_schema.columns WHERE table_schema='atlas_db'
               AND table_name IN (SELECT table_name FROM information_schema.tables
                                   WHERE table_schema='atlas_db' AND table_type='BASE TABLE')
             ORDER BY table_name, ordinal_position""")
fks = q("""SELECT table_name, column_name, referenced_table_name, referenced_column_name, constraint_name
             FROM information_schema.key_column_usage
            WHERE table_schema='atlas_db' AND referenced_table_name IS NOT NULL
            ORDER BY table_name, constraint_name, ordinal_position""")
checks = q("""SELECT tc.table_name, cc.constraint_name, cc.check_clause
                FROM information_schema.check_constraints cc
                JOIN information_schema.table_constraints tc
                  ON tc.constraint_schema = cc.constraint_schema AND tc.constraint_name = cc.constraint_name
               WHERE cc.constraint_schema='atlas_db' ORDER BY tc.table_name, cc.constraint_name""")

por_tabla = defaultdict(list)
for t, c, tipo, nul, key, default, extra in cols:
    por_tabla[t].append((c, tipo, nul, key, default, extra))
fk_col = {(t, c): (rt, rc) for t, c, rt, rc, _ in fks}
chk = defaultdict(list)
for t, n, clause in checks:
    chk[t].append((n, clause))

# ---- DER en Mermaid ----
lineas = ["erDiagram"]
for t in sorted(por_tabla):
    lineas.append(f"    {t} {{")
    for c, tipo, nul, key, *_ in por_tabla[t]:
        base = tipo.split("(")[0].split(" ")[0]
        marca = "PK" if key == "PRI" else ("FK" if (t, c) in fk_col else ("UK" if key == "UNI" else ""))
        if key == "PRI" and (t, c) in fk_col:
            marca = "PK,FK"
        lineas.append(f"        {base} {c} {marca}".rstrip())
    lineas.append("    }")
vistos = set()
for t, c, rt, rc, cname in fks:
    if (t, cname) in vistos:
        continue
    vistos.add((t, cname))
    lineas.append(f'    {rt} ||--o{{ {t} : "{c}"')
with open(f"{salida}/der.mmd", "w") as f:
    f.write("\n".join(lineas) + "\n")

# ---- Diccionario ----
md = ["# Diccionario de datos — atlas_db", "",
      "Generado automáticamente desde `information_schema` de la base en ejecución "
      "(`database/tools/generar_documentacion.py`). No editar a mano.", ""]
for grupo, tablas in GRUPOS.items():
    md += [f"## {grupo}", ""]
    for t in tablas:
        md += [f"### `{t}`", "", "| Columna | Tipo | Nulo | Clave | Por defecto | Referencia |", "| --- | --- | --- | --- | --- | --- |"]
        for c, tipo, nul, key, default, extra in por_tabla[t]:
            ref = "→ `{}.{}`".format(*fk_col[(t, c)]) if (t, c) in fk_col else ""
            d = (default + (" " + extra if extra else "")).strip().replace("|", "\\|")
            md.append(f"| `{c}` | {tipo.replace('|', chr(92) + '|')} | {nul} | {key} | {d} | {ref} |")
        if chk[t]:
            md += ["", "Restricciones CHECK:", ""]
            for n, clause in chk[t]:
                md.append(f"- `{n}`: `{clause.replace('`', '')}`")
        md.append("")
with open(f"{salida}/diccionario-datos.md", "w") as f:
    f.write("\n".join(md))
print(f"tablas={len(por_tabla)} columnas={len(cols)} fks={len({(t, n) for t, _, _, _, n in fks})} checks={len(checks)}")
