# Fase 5 — Base de datos

| Campo | Valor |
| --- | --- |
| Fecha | 26/09/2026 · Hito 2: 20/10/2026 (migración 003) y **22/10/2026 (migración 004, ver al final)** |
| Estado | **Implementada y verificada** en MySQL 8.0.46 real (contenedor efímero en el entorno de desarrollo). Falta desplegarla en atlas-srv01 (Fase 13) |
| Diseño | [fase-02/03-modelo-datos](../fase-02-arquitectura/03-modelo-datos.md) |

## Devolución del Hito 2: dónde está cada entregable

| Lo que pidió el profesor de Base de Datos | Entregable | Evidencia |
| --- | --- | --- |
| DER completo y diccionario, en correspondencia con las tablas y las **reglas de negocio** | DER generado desde la base real: completo ([SVG](img/der.svg), [PNG](img/der.png), [Mermaid](der.mmd)) y **por área** ([Identidad](img/der-identidad.svg), [Contenido](img/der-contenido.svg), [Interacción](img/der-interaccion.svg), [Análisis](img/der-analisis.svg), [Control](img/der-control.svg)) · [diccionario](diccionario-datos.md) · **[reglas de negocio → restricción → prueba](reglas-de-negocio.md)** (47 reglas) | Regenerados el 22/10 desde una instalación limpia: idénticos a los del repositorio |
| Script SQL reproducible con claves, relaciones, restricciones e índices | `database/migrations/001`–`004` + `seeds/` + `docker/mysql/init.sql` | E-BD-008 §1: instalación desde cero → 32 tablas, 48 FK, 38 CHECK, 92 índices, 13 triggers |
| Usuarios y privilegios, **demostrando que lo no autorizado se rechaza** | 5 usuarios con privilegio mínimo (`02-usuarios.sh`) · `tools/demostrar_rechazos.sh` | **E-BD-011**: 36 rechazos con el error real de MySQL + 4 controles permitidos, 0 que no coinciden · E-BD-010 (SHOW GRANTS) · `PrivilegiosTest` (E-BD-007) |
| Datos representativos y consultas de prueba con rendimiento | `tools/datos_representativos.sql` (300 estudiantes, 9.000 intentos) · `tools/pruebas_hito2.sh` | E-BD-006 / E-BD-008 (tiempos y `EXPLAIN ANALYZE`) |
| Restauración real con tiempos e integridad | Completo (`mysqldump`) + incremental (binlog) | E-BD-005 / E-BD-009: RPO 0, CHECKSUM sin diferencias, 0 huérfanos |
| *Recomendación:* alta disponibilidad con replicación y conmutación, qué resuelve y por qué no reemplaza al respaldo | **[alta-disponibilidad.md](alta-disponibilidad.md)** · `tools/demostrar_replicacion.sh` | **E-BD-012**: réplica idéntica, solo lectura, un borrado por error se replica en 0,7 s, conmutación con RPO 0 y RTO < 1 s (Docker de desarrollo) |

## Archivos

| Archivo | Qué es |
| --- | --- |
| `atlas/database/migrations/001_esquema.sql` | 29 tablas, claves, FK, CHECK, índices |
| `atlas/database/migrations/002_logica.sql` | 17 triggers, 5 vistas, `sp_analisis_grupal` (la 004 borra el procedimiento y los 7 triggers que calculaban o escribían) |
| `atlas/database/migrations/004_calculos_en_php.sql` | Hito 2, acta D-4/D-2/D-6/D-8: la base deja de calcular; aprobación por defecto desactivada; `decisiones_recomendacion`; `intentos.duracion_activa_seg` |
| `atlas/database/seeds/001_catalogos.sql` | Roles, permisos, estados, niveles, categorías, institución, **reglas R01–R08** |
| `atlas/docker/mysql/init.sql` | Punto de entrada del contenedor atlas-db (§26.2) |
| `atlas/docker/mysql/02-usuarios.sh` | Los 5 usuarios de MySQL; contraseñas desde variables de entorno |
| `atlas/tests/Database/*` | 45 tests PHPUnit + `run.sh` (levanta un MySQL 8.0 real y efímero) |
| `atlas/database/tools/generar_documentacion.py` | Genera el DER y el diccionario desde la base en ejecución |
| [der.mmd](der.mmd) | Diagrama entidad-relación (Mermaid), regenerado el 22/10 desde la base con 004: **32 tablas y 48 FK** |
| [diccionario-datos.md](diccionario-datos.md) | Diccionario regenerado el 22/10: **196 columnas, 38 restricciones CHECK** |

Para reproducir: `atlas/tests/Database/run.sh` (con `ATLAS_TEST_MYSQL_IMAGE=mirror.gcr.io/library/mysql:8.0` si Docker Hub limita las descargas).

## Trazabilidad: requisito → implementación → prueba → evidencia

| Requisito | Implementación | Prueba | Evidencia | Resultado |
| --- | --- | --- | --- | --- |
| OBJ-04 / BD-02: ≥ 15 tablas, 3FN | 29 tablas; única desnormalización `resultados.puntaje` (§27.3) | `EsquemaTest::testExistenLas29Tablas…` | E-BD-001 | PASS |
| BD-06: FK en todas las relaciones | 43 FK; todas las columnas `*_id` con FK (salvo `auditoria.recurso_id`, identificador libre) | `EsquemaTest::testCadaColumnaTerminadaEnId…`, `IntegridadTest::testClaveForanea…` | E-BD-001 | PASS |
| BD-06: CHECK de puntajes y tiempos | 35 CHECK | `IntegridadTest` (puntaje, cierre de intento, indicadores) | E-BD-001 | PASS |
| BD-06: índice (usuario_id, actividad_id) | `ix_intentos_usuario_actividad` | `EsquemaTest::testIndiceCompuesto…` | E-BD-001 | PASS |
| BD-06: resultados (Hito 1: trigger) | Desde 004 el puntaje lo calcula PHP y la base lo guarda; un resultado por intento, `correctas ≤ total`, `atlas_app` sin UPDATE/DELETE | `ResultadosTest`, `PrivilegiosTest`; puntaje en `IndicadoresTest` y `ResolucionTest` | E-BD-007, E-APP-007, E-APP-008 | PASS |
| BD-06: vistas (Hito 1: + procedimiento) | 5 vistas; el análisis grupal lo calcula PHP (`ResumenGrupal`) y se guarda en `analisis_grupal` | `AnalisisGrupalTest`, `ResumenGrupalTest`, `PanelGrupalTest` | E-BD-007, E-APP-007, E-APP-008 | PASS |
| BD-07: privilegios diferenciados | `02-usuarios.sh` | `PrivilegiosTest` (11 casos) + `SHOW GRANTS` | E-BD-001, E-BD-002 | PASS |
| BD-08: MySQL no accesible desde la red | atlas_admin solo `localhost`; resto solo desde `atlas_back` | `PrivilegiosTest::testAdminSoloDesdeDentro…` | E-BD-001 | PASS (a nivel de BD; la prueba de red es P-03, Fase 14) |
| RF-01: correo único, campos obligatorios | `uq_usuarios_correo`, CHECK | `IntegridadTest` | E-BD-001 | PASS |
| RF-07 / RF-08 / RF-09 | `intentos`, `resultados`, trigger | `ResultadosTest` (6 casos) | E-BD-001 | PASS |
| RF-06: secuencia reconstruible | `interacciones` con `UNIQUE(intento_id, secuencia)` | `IntegridadTest::testSecuencia…` | E-BD-001 | PASS |
| RF-15: auditoría no modificable | Triggers inmutables + solo INSERT para atlas_app | `AuditoriaTest`, `PrivilegiosTest` | E-BD-001 | PASS |
| RF-14: autor y fecha en cambios administrativos | Hito 1: triggers con `@atlas_usuario_id`. Desde 004: el middleware de auditoría registra autor, fecha y antes/después (los triggers duplicaban el registro) | `GestionAdministrativaTest`, `AuditoriaTest::testLaBaseNoCalculaNiEscribeAuditoriaPorSuCuenta` | E-APP-008, E-BD-007 | PASS |
| RF-16 / RF-17: ciclo de 5 estados | `trg_actividades_ciclo`, `transiciones_actividad` | `CicloActividadTest` (6 casos) | E-BD-001 | PASS |
| ANA-05 / ANA-06: 8 reglas en BD, editables y versionadas | Semilla R01–R08; la versión la sube la aplicación al editar (Hito 1: `trg_reglas_version`) | `EsquemaTest::testCatalogosSemilla`, `MotorAnalisisApiTest::testEditarUnaReglaCambiaElResultadoYVersiona` | E-BD-007, E-APP-008 | PASS |
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
| H5-H2-04 | La regla "cada pregunta tiene al menos una habilidad" todavía no se exige en la base | **Resuelto (22/10)**: el editor carga las habilidades y la aplicación exige al menos una por pregunta para enviar o publicar (`CicloAprobacionApiTest::testSinHabilidadesNoSeEnviaNiSePublica`). En la base no se agregó un trigger: un borrador puede guardarse incompleto |
| H5-H2-02 (seguimiento) | `v_preguntas_error` lenta | **Resuelto en la aplicación (22/10)**: el panel ya no usa la vista; arranca por el grupo y filtra por período (`ReporteRepository::preguntasConMasError`). La vista sigue disponible para `atlas_read` |

## Hito 2 — Migración 004: la base guarda y protege, la aplicación calcula (22/10/2026)

Acta del Hito 2 (devolución de Programación): **D-4** los indicadores y cálculos se hacen en PHP y MySQL solo guarda y protege la integridad; **D-2** la aprobación es configurable y por defecto no se exige; **D-6** el docente decide sobre la actividad sugerida; **D-8** se muestra el tiempo activo aparte del total.

| Cambio | Antes (Hito 1 / 003) | Ahora (004) | Por qué sigue protegida la integridad |
| --- | --- | --- | --- |
| Puntaje del intento | `trg_intentos_finalizar` lo calculaba | `IntentoService::finalizar` lo calcula en PHP y lo inserta en la misma transacción que el cierre | `uq_resultados_intento`, `ck_resultados_puntaje`, `ck_resultados_correctas`; `atlas_app` puede agregar pero **no** modificar ni borrar resultados; un intento cerrado no se reabre (`trg_intentos_inmutable_cerrado`) |
| Análisis grupal | `sp_analisis_grupal` | `ResumenGrupal` (PHP); se guarda el historial en `analisis_grupal` | `ck_analisis_grupal_rangos` y `_periodo`; `atlas_app` solo agrega |
| Versión de las reglas y auditoría de cambios | `trg_reglas_version` y 5 triggers que escribían en `auditoria` | La aplicación versiona y el middleware audita con antes/después | `auditoria` sigue sin UPDATE/DELETE (`trg_auditoria_sin_update`/`_delete`) |
| Aprobación por defecto | `requiere_aprobacion DEFAULT TRUE` | `DEFAULT FALSE` (las instituciones existentes conservan su valor) | `trg_actividades_ciclo` sigue validando cada transición |
| Decisión del docente (D-6) | — | Tabla `decisiones_recomendacion` (una por recomendación) | FK a recomendación, actividad y docente; `UNIQUE (recomendacion_id)`; `atlas_app` sin UPDATE/DELETE |
| Tiempo activo (D-8) | — | `intentos.duracion_activa_seg` (NULL en intentos previos) | `ck_intentos_duracion_activa` (activo ≤ total) |

Quedan **13 triggers, todos de integridad** (rechazan lo inválido, no calculan ni escriben datos), **0 procedimientos**, 5 vistas, 32 tablas, 48 FK y 38 CHECK.

| Archivo | Qué es |
| --- | --- |
| `atlas/database/migrations/004_calculos_en_php.sql` | La migración (idempotente) |
| `atlas/database/seeds/003_permisos_hito2.sql` | Permiso `recomendaciones.decidir` para DOCENTE |
| `atlas/database/tools/actualizar_a_004.sh` | Aplica 004 y los permisos nuevos a una base ya instalada, sin borrar datos |
| `atlas/database/tools/datos_representativos.sql` | Ahora guarda los resultados con el mismo cálculo que la aplicación (antes los generaba el trigger) |

### Resultados (ejecutados el 22/10/2026)

| Prueba | Resultado | Evidencia |
| --- | --- | --- |
| Suite de base de datos | **58 pruebas aprobadas** | E-BD-007 |
| Consistencia de `resultados.puntaje` con el cálculo en PHP (8.749 resultados recalculados desde respuestas) | **0 inconsistencias**, 0 finalizados sin resultado, 0 abandonados con resultado | E-BD-008 §4 |
| Instalación desde cero | 32 tablas, 5 vistas, 13 triggers, 0 rutinas, 48 FK, 38 CHECK | E-BD-008 §1 |
| Restauración real con 004 (completo + binlog) | RPO 0 · CHECKSUM de 32 tablas sin diferencias · 0 huérfanos · triggers y vistas recuperados. RTO 21 s **en Docker anidado** (no comparable con los 4 s de E-BD-005) | E-BD-009 |
| Privilegios | `atlas_app`: SELECT e INSERT en `resultados`, `analisis_grupal`, `decisiones_recomendacion`; sin EXECUTE (no hay procedimientos) | E-BD-010 |

E-BD-005 y E-BD-006 (20/10, antes de 004) se conservan sin cambios como registro de lo evaluado.
