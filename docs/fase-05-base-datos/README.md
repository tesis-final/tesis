# Fase 5 — Base de datos

| Campo | Valor |
| --- | --- |
| Fecha | 26/09/2026 |
| Estado | **Implementada y verificada** en MySQL 8.0.46 real (contenedor efímero en el entorno de desarrollo). Falta desplegarla en atlas-srv01 (Fase 13) |
| Diseño | [fase-02/03-modelo-datos](../fase-02-arquitectura/03-modelo-datos.md) |

## Archivos

| Archivo | Qué es |
| --- | --- |
| `atlas/database/migrations/001_esquema.sql` | 29 tablas, claves, FK, CHECK, índices |
| `atlas/database/migrations/002_logica.sql` | 17 triggers, 5 vistas, `sp_analisis_grupal` |
| `atlas/database/seeds/001_catalogos.sql` | Roles, permisos, estados, niveles, categorías, institución, **reglas R01–R08** |
| `atlas/docker/mysql/init.sql` | Punto de entrada del contenedor atlas-db (§26.2) |
| `atlas/docker/mysql/02-usuarios.sh` | Los 5 usuarios de MySQL; contraseñas desde variables de entorno |
| `atlas/tests/Database/*` | 45 tests PHPUnit + `run.sh` (levanta un MySQL 8.0 real y efímero) |
| `atlas/database/tools/generar_documentacion.py` | Genera el DER y el diccionario desde la base en ejecución |
| [der.mmd](der.mmd) | Diagrama entidad-relación (Mermaid), 29 tablas y 43 FK |
| [diccionario-datos.md](diccionario-datos.md) | Diccionario: 181 columnas, 35 restricciones CHECK |

Para reproducir: `atlas/tests/Database/run.sh` (con `ATLAS_TEST_MYSQL_IMAGE=mirror.gcr.io/library/mysql:8.0` si Docker Hub limita las descargas).

## Trazabilidad: requisito → implementación → prueba → evidencia

| Requisito | Implementación | Prueba | Evidencia | Resultado |
| --- | --- | --- | --- | --- |
| OBJ-04 / BD-02: ≥ 15 tablas, 3FN | 29 tablas; única desnormalización `resultados.puntaje` (§27.3) | `EsquemaTest::testExistenLas29Tablas…` | E-BD-001 | PASS |
| BD-06: FK en todas las relaciones | 43 FK; todas las columnas `*_id` con FK (salvo `auditoria.recurso_id`, identificador libre) | `EsquemaTest::testCadaColumnaTerminadaEnId…`, `IntegridadTest::testClaveForanea…` | E-BD-001 | PASS |
| BD-06: CHECK de puntajes y tiempos | 35 CHECK | `IntegridadTest` (puntaje, cierre de intento, indicadores) | E-BD-001 | PASS |
| BD-06: índice (usuario_id, actividad_id) | `ix_intentos_usuario_actividad` | `EsquemaTest::testIndiceCompuesto…` | E-BD-001 | PASS |
| BD-06: triggers de resultados | `trg_intentos_finalizar` | `ResultadosTest` (75 %, 25 %, abandonado sin resultado) | E-BD-001 | PASS |
| BD-06: vistas y procedimiento | 5 vistas + `sp_analisis_grupal` | `AnalisisGrupalTest` (promedio 62,5; mediana; último intento) | E-BD-001 | PASS |
| BD-07: privilegios diferenciados | `02-usuarios.sh` | `PrivilegiosTest` (11 casos) + `SHOW GRANTS` | E-BD-001, E-BD-002 | PASS |
| BD-08: MySQL no accesible desde la red | atlas_admin solo `localhost`; resto solo desde `atlas_back` | `PrivilegiosTest::testAdminSoloDesdeDentro…` | E-BD-001 | PASS (a nivel de BD; la prueba de red es P-03, Fase 14) |
| RF-01: correo único, campos obligatorios | `uq_usuarios_correo`, CHECK | `IntegridadTest` | E-BD-001 | PASS |
| RF-07 / RF-08 / RF-09 | `intentos`, `resultados`, trigger | `ResultadosTest` (6 casos) | E-BD-001 | PASS |
| RF-06: secuencia reconstruible | `interacciones` con `UNIQUE(intento_id, secuencia)` | `IntegridadTest::testSecuencia…` | E-BD-001 | PASS |
| RF-15: auditoría no modificable | Triggers inmutables + solo INSERT para atlas_app | `AuditoriaTest`, `PrivilegiosTest` | E-BD-001 | PASS |
| RF-14: autor y fecha en cambios administrativos | Triggers con `@atlas_usuario_id` | `AuditoriaTest::testCambioDeUsuario…` | E-BD-001 | PASS |
| RF-16 / RF-17: ciclo de 5 estados | `trg_actividades_ciclo`, `transiciones_actividad` | `CicloActividadTest` (6 casos) | E-BD-001 | PASS |
| ANA-05 / ANA-06: 8 reglas en BD, editables y versionadas | Semilla R01–R08; `trg_reglas_version` | `EsquemaTest::testCatalogosSemilla`, `AuditoriaTest::testEditarUnaRegla…` | E-BD-001 | PASS |
| RNF-14: vistas sin datos innecesarios | Vistas sin correo ni hash | `EsquemaTest::testNingunaVista…` | E-BD-001 | PASS |
| BD-11: DER, diccionario, script, usuarios, datos de prueba | Archivos de arriba | Generados desde la base real | der.mmd, diccionario | Cumplido (los datos de prueba sintéticos van con la Fase 4) |

## Registro de hallazgos durante la fase

| # | Hallazgo | Tratamiento |
| --- | --- | --- |
| 1 | En la primera corrida falló 1 de 45 tests: comparaba un valor JSON contra un texto | Se corrigió **el test** (el trigger funcionaba bien, verificado a mano). Segunda corrida: 45/45 |
| 2 | Para quitar preguntas u opciones de un borrador (RF-16), atlas_app necesita DELETE, que la Tabla 21 no lista | **CT-13**: DELETE solo sobre `preguntas` y `opciones`, limitado por trigger a actividades en BORRADOR |
| 3 | Docker Hub respondió 429 (límite de descargas anónimas) | Se usó el mirror oficial `mirror.gcr.io/library/mysql:8.0` (misma imagen) |

## Lo que todavía NO está verificado

- El despliegue en atlas-srv01 real con `/srv/atlas/datos` y UID 5003 (Fases 6 y 13).
- El respaldo con `atlas_backup` (Fase 12).
- P-03 (3306 inaccesible desde VLAN 30): es una prueba de red (Fase 14).

## Hito 2 — Lo que se agregó y se probó

Devolución de Base de Datos (Hito 1): DER y diccionario que coincidan con las tablas · script reproducible con claves, relaciones, restricciones e índices · usuarios y privilegios con rechazos demostrados · datos representativos y consultas con rendimiento · restauración real con tiempos e integridad · pruebas de la excepción a la 3FN. Devolución de Programación 4.a y 4.c: habilidades por pregunta y aprobación configurable.

| Archivo | Qué es |
| --- | --- |
| `atlas/database/migrations/003_habilidades_aprobacion.sql` | Tablas `habilidades` y `pregunta_habilidad` (N:M), columna `instituciones.requiere_aprobacion`, triggers de edición en borrador y ciclo de aprobación con la transición BORRADOR → PUBLICADA cuando la institución no exige aprobación |
| `atlas/database/seeds/002_habilidades.sql` | Las 4 habilidades de ejemplo de la devolución |
| `atlas/docker/mysql/init.sql`, `02-usuarios.sh` | Instalación desde cero con 003 y los permisos mínimos de `atlas_app` sobre las tablas nuevas |
| `atlas/database/tools/actualizar_a_003.sh` | Aplica 003 a una base ya instalada, sin borrar datos (idempotente: probado dos veces seguidas) |
| `atlas/database/tools/datos_representativos.sql` | Datos sintéticos y reproducibles (CRC32, sin RAND): 300 estudiantes, 30 actividades, 9.000 intentos, ~88.700 respuestas, pasando por todos los triggers |
| `atlas/database/tools/pruebas_hito2.sh` | Instalación desde cero + datos + consultas con tiempos + consistencia de la 3FN + ejercicio de restauración (RPO/RTO) |
| `atlas/tests/Database/HabilidadesAprobacionTest.php` | 13 pruebas de claves, restricciones, triggers y privilegios de lo nuevo |
| `der.mmd`, `diccionario-datos.md` | Regenerados desde la base real (31 tablas, 189 columnas, 45 FK, 37 CHECK) |

### Resultados (ejecutados el 2026-10-20 sobre MySQL 8.0.46 en Docker de desarrollo)

| Prueba | Resultado | Evidencia |
| --- | --- | --- |
| Suite de base de datos (incluye las 13 nuevas) | **58 pruebas aprobadas** | E-BD-001 |
| Regresión de la API contra MySQL real (la app sigue funcionando con 003) | **58 pruebas aprobadas** | E-APP-002 |
| Regresión unitaria PHP | **26 pruebas aprobadas** | `vendor/bin/phpunit --testsuite unit` |
| Privilegios (SHOW GRANTS de los 6 usuarios) | Permisos nuevos solo para `atlas_app` | E-BD-002 |
| Consistencia de `resultados.puntaje` (8.749 resultados recalculados) | 0 inconsistencias | E-BD-006 §4 |
| Rendimiento de la excepción a la 3FN | Promedio por estudiante de un grupo: **2,7 ms** con el puntaje guardado contra **24,5 ms** recalculándolo (≈9 veces) | E-BD-006 Q1 / Q1b |
| Restauración real (completo + binlog) | **RTO ≈ 4 s** (objetivo 4 h) · **RPO 0** con incremental (sin él se perdían los 50 intentos posteriores al respaldo) · CHECKSUM de 31 tablas sin diferencias · 0 huérfanos | E-BD-005 |

### Hallazgos

| ID | Hallazgo | Qué se hizo / falta |
| --- | --- | --- |
| H5-H2-01 | La imagen oficial `mysql:8.0` no trae `mysqlbinlog`: el incremental no se puede aplicar desde el contenedor de producción | En la prueba se usó `mysql:8.0-debian` (misma versión) como herramienta auxiliar. El script de respaldo (Fase 12) tiene que hacer lo mismo |
| H5-H2-02 | `v_preguntas_error` tarda ~490 ms con 88.700 respuestas aunque se filtre por grupo: MySQL materializa la vista entera (tiene GROUP BY) | La misma consulta arrancando por el grupo tarda ~41 ms (Q5b). Recomendación para Programación (consultas guiadas): usar la consulta parametrizada |
| H5-H2-03 | Las pruebas corren en Docker de desarrollo, no en atlas-srv01 | Repetir `pruebas_hito2.sh` y la restauración en el servidor (manual del Hito 2) |
| H5-H2-04 | La regla "cada pregunta tiene al menos una habilidad" todavía no se exige en la base | Se exigirá cuando el editor de preguntas las cargue (tarea P-04 de Programación); antes rompería la creación de actividades |
