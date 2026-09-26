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
