# Reglas de negocio → implementación en la base → prueba

Devolución de Base de Datos (Hito 2): *"Presentar el DER completo y el diccionario de datos, asegurando su correspondencia con las tablas y reglas de negocio descritas."*

Este documento une las tres cosas: cada **regla de negocio** (de dónde sale en el PDF o en el acta), **qué objeto de la base la garantiza** (restricción, clave, trigger o privilegio, con el nombre exacto que figura en el [diccionario](diccionario-datos.md) y en el [DER](der.mmd)) y **qué prueba la verifica** (todas en `atlas/tests/Database/`, evidencia E-BD-007, salvo que se indique otra).

Desde el Hito 2 (acta D-4) la base **no calcula**: guarda los datos y rechaza lo que viola una regla. Donde una regla la cumple la aplicación (porque es un cálculo), se indica igual, junto con la barrera que pone la base.

Convención de la columna "Cómo": **PK/UNIQUE** = clave · **FK** = clave foránea · **CHECK** = restricción de dominio · **TRG** = trigger que rechaza (`SIGNAL 45000`) · **PRIV** = privilegio de MySQL (lo que no está concedido, MySQL lo rechaza con `ERROR 1142`).

## 1. Usuarios, roles y acceso (RF-01, RF-02, RF-03, RF-14)

| # | Regla de negocio | Origen | Cómo la garantiza la base | Prueba |
| --- | --- | --- | --- | --- |
| U1 | Cada usuario se identifica por un correo único | RF-01 (H9) | UNIQUE `uq_usuarios_correo` | `IntegridadTest::testCorreoDuplicadoRechazadoRf01` |
| U2 | Nombre, apellido y correo son obligatorios y no pueden quedar en blanco | RF-01 (H9) | NOT NULL + CHECK `ck_usuarios_nombre`, `ck_usuarios_apellido`, `ck_usuarios_correo` | `IntegridadTest::testCamposObligatoriosVaciosRechazadosRf01` |
| U3 | Hay exactamente tres roles: administrador, docente y estudiante | RF-03 | CHECK `ck_roles_codigo` + UNIQUE `uq_roles_codigo` | `EsquemaTest::testCatalogosSemilla` |
| U4 | Todo usuario pertenece a un rol y a una institución que existen | RF-03, RF-14 | FK `usuarios.rol_id`, `usuarios.institucion_id` | `IntegridadTest::testClaveForaneaRechazaReferenciaInexistente` |
| U5 | Los permisos de cada rol están en la base (no en el código) | RF-03, Tabla 21 | PK compuesta `rol_permiso (rol_id, permiso_id)` + FK | `EsquemaTest::testCatalogosSemilla` |
| U6 | La contraseña nunca se guarda en claro; los intentos fallidos y el bloqueo quedan registrados | RF-02 (H10) | Columnas `hash_contrasena` (Argon2id), `intentos_fallidos`, `bloqueado_hasta`; ninguna vista expone hash ni correo | `EsquemaTest::testNingunaVistaExponeCorreoNiHash`; el bloqueo, en `AutenticacionTest` (API) |
| U7 | Un usuario no se borra: se desactiva | RF-14 | PRIV: `atlas_app` no tiene DELETE sobre `usuarios` | `PrivilegiosTest::testAppNoPuedeCambiarEstructuraNiBorrarUsuarios` |
| U8 | Un grupo no se repite en la misma institución y año | §27.1 | UNIQUE `uq_grupos (institucion_id, nombre, anio_lectivo)` + CHECK `ck_grupos_anio` | Demostrado en E-BD-011 (duplicado y año fuera de rango rechazados) |

## 2. Actividades y ciclo de aprobación (RF-05, RF-16, RF-17; acta D-2, D-3)

| # | Regla de negocio | Origen | Cómo la garantiza la base | Prueba |
| --- | --- | --- | --- | --- |
| A1 | Una actividad tiene título, autor, nivel, categoría y estado válidos | RF-05, RF-16 | NOT NULL + CHECK `ck_actividades_titulo` + FK a `usuarios`, `niveles_dificultad`, `categorias`, `estados_actividad` | `IntegridadTest::testClaveForaneaRechazaReferenciaInexistente` |
| A2 | Los estados son cinco: borrador, pendiente, aprobada, rechazada, publicada | RF-17 (H25) | CHECK `ck_estados_codigo` | `CicloActividadTest::testRecorridoCompletoPorLosCincoEstados` |
| A3 | Solo se permiten estas transiciones: borrador→pendiente→aprobada/rechazada; rechazada→borrador; aprobada→publicada; **borrador→publicada solo si la institución no exige aprobación** | RF-17, §25.3, **D-2** | TRG `trg_actividades_ciclo` (lee `instituciones.requiere_aprobacion` del autor) | `CicloActividadTest::testTransicionNoPermitidaRechazada`, `HabilidadesAprobacionTest::testConAprobacionNoSePublicaDirecto`, `testSinAprobacionElDocentePublicaDirecto`, `testSinAprobacionNoSeEnviaAPendiente` |
| A4 | Por defecto una institución **no** exige aprobación | **D-2** | DEFAULT `requiere_aprobacion = FALSE` (migración 004) | `HabilidadesAprobacionTest::testPorDefectoLaInstitucionNoExigeAprobacion` |
| A5 | Una actividad sin preguntas no puede enviarse ni publicarse | RF-16 (H24) | TRG `trg_actividades_ciclo` (al pasar a pendiente o a publicada) | `CicloActividadTest::testActividadSinPreguntasNoSeEnviaAAprobacion`, `HabilidadesAprobacionTest::testPublicarDirectoTambienValidaElContenido` |
| A6 | Cada pregunta tiene al menos 2 opciones y exactamente 1 correcta | RF-16 (H24) | TRG `trg_actividades_ciclo` | `CicloActividadTest::testPreguntaConDosCorrectasNoSeEnvia` |
| A7 | El contenido (preguntas, opciones, habilidades) solo se edita mientras la actividad está en borrador | RF-16, CT-13 | TRG `trg_preguntas_*_solo_borrador`, `trg_opciones_*_solo_borrador`, `trg_pregunta_habilidad_ins/del/upd` | `CicloActividadTest::testContenidoInmutableFueraDeBorrador`, `HabilidadesAprobacionTest::testVinculosSoloSeEditanEnBorrador`, `PrivilegiosTest::testAppPuedeBorrarContenidoSoloEnBorradorCt13` |
| A8 | Cada cambio de estado queda registrado con su autor y, si se rechaza, con observaciones | RF-17 (H25), §25.3 | Tabla `transiciones_actividad` (FK a usuario) + PRIV: `atlas_app` solo INSERT (no puede alterar el historial) | `CicloActividadTest::testTransicionesRegistranAutorYObservaciones`, `PrivilegiosTest::testAppNoModificaTransicionesNiConversaciones` |
| A9 | El orden de preguntas y opciones no se repite dentro de su actividad | §27.1 | UNIQUE `uq_preguntas_orden`, `uq_opciones_orden` | Demostrado en E-BD-011 (orden repetido rechazado) |
| A10 | Una pregunta mide una o más habilidades, sin repetir el par | **D-3** | PK compuesta `pregunta_habilidad (pregunta_id, habilidad_id)` + FK | `HabilidadesAprobacionTest::testUnaPreguntaPuedeMedirVariasHabilidadesSinRepetir`, `testClavesForaneasRechazanPreguntaOHabilidadInexistente` |
| A11 | Una habilidad desactivada no se asigna; una habilidad en uso no se borra | **D-3** | TRG `trg_pregunta_habilidad_ins` + FK sin `ON DELETE` | `HabilidadesAprobacionTest::testHabilidadDesactivadaNoSeAsignaYHabilidadEnUsoNoSeBorra` |
| A12 | Para publicar, cada pregunta tiene que medir al menos una habilidad | **D-3** | Lo exige la aplicación (`ActividadService`); en la base no hay trigger porque un borrador se guarda incompleto | `CicloAprobacionApiTest::testSinHabilidadesNoSeEnviaNiSePublica` (API, E-APP-008) |

## 3. Resolución: intentos, respuestas, eventos y tiempos (RF-06 a RF-09; acta D-8)

| # | Regla de negocio | Origen | Cómo la garantiza la base | Prueba |
| --- | --- | --- | --- | --- |
| R1 | Cada inicio es un intento distinguible (número correlativo por estudiante y actividad) | RF-08 (H16) | UNIQUE `uq_intentos_numero (usuario_id, actividad_id, numero_intento)` + CHECK `ck_intentos_numero` | `ResultadosTest::testCadaInicioEsUnIntentoDistinguible` |
| R2 | Un intento cerrado (finalizado o abandonado) tiene fecha de cierre y duración; uno en curso no | RF-08, RF-09 | CHECK `ck_intentos_cierre`, `ck_intentos_duracion` | `IntegridadTest::testIntentoCerradoDebeTenerFechaYDuracion` |
| R3 | Un intento cerrado no se reabre | RF-08 | TRG `trg_intentos_inmutable_cerrado` | `ResultadosTest::testIntentoCerradoNoSeReabre` |
| R4 | Solo se responde un intento en curso, y solo preguntas de su actividad | RF-06 | TRG `trg_respuestas_validar`, `trg_respuestas_validar_upd` | `ResultadosTest::testNoSeRespondeUnIntentoCerradoNiOtraActividad` |
| R5 | La opción elegida pertenece a la pregunta respondida | RF-06 | FK compuesta `fk_respuestas_opcion (opcion_id, pregunta_id) → opciones (id, pregunta_id)` | `IntegridadTest::testOpcionDebePertenecerALaPreguntaRespondida` |
| R6 | Una respuesta por pregunta y por intento (cambiar de opción la reemplaza; el cambio queda como evento) | RF-06 | UNIQUE `uq_respuestas_intento_pregunta` | Demostrado en E-BD-011 (segunda respuesta a la misma pregunta rechazada) |
| R7 | Los eventos se pueden reconstruir en orden y no se duplican si se reenvían | RF-06 (H14) | UNIQUE `uq_interacciones_secuencia (intento_id, secuencia)` + CHECK `ck_interacciones_opcion` | `IntegridadTest::testSecuenciaDeInteraccionesUnicaPorIntento` |
| R8 | Los tiempos están en segundos y acotados (≤ 24 h) | RF-09 (H17) | CHECK `ck_intentos_duracion`, `ck_respuestas_tiempo` | Demostrado en E-BD-011 (tiempo mayor a 24 h rechazado) |
| R9 | El tiempo activo (total menos pausas) nunca supera al total | **D-8** | CHECK `ck_intentos_duracion_activa` (migración 004) | `ResultadosTest::testTiempoActivoNoSuperaAlTotal` |

## 4. Resultados y la excepción a la 3FN (RF-07, §27.3; acta D-4)

| # | Regla de negocio | Origen | Cómo la garantiza la base | Prueba |
| --- | --- | --- | --- | --- |
| P1 | El puntaje es correctas / total × 100 y se guarda una sola vez al finalizar (única desnormalización) | RF-07, §27.3, **D-4** | Lo calcula la aplicación; la base lo protege: UNIQUE `uq_resultados_intento` (uno por intento), CHECK `ck_resultados_puntaje` (0–100) y `ck_resultados_correctas` (correctas ≤ total) | `ResultadosTest::testUnSoloResultadoPorIntentoYCoherente`, `IntegridadTest::testPuntajeFueraDeRangoRechazado` |
| P2 | El resultado no se puede alterar después de guardado | RF-07, §27.3 | PRIV: `atlas_app` solo SELECT e INSERT sobre `resultados` (sin UPDATE ni DELETE); el intento cerrado no se reabre (R3) | `PrivilegiosTest::testAppNoPuedeFalsearResultados` |
| P3 | Un intento abandonado no genera resultado | RF-07 (H15) | La aplicación no lo inserta; la base no calcula nada al cerrar | `ResultadosTest::testIntentoAbandonadoNoGeneraResultado`, `testLaBaseNoCalculaElResultado` |
| P4 | El puntaje guardado coincide siempre con el que sale de las respuestas | §27.3 | P1 + P2 + R3/R4 | Consistencia sobre 8.749 resultados: **0 inconsistencias** (E-BD-008 §4) |

## 5. Análisis, reglas y recomendaciones (RF-10 a RF-12, RF-18, RF-19; acta D-4, D-6, D-7)

| # | Regla de negocio | Origen | Cómo la garantiza la base | Prueba |
| --- | --- | --- | --- | --- |
| N1 | Cada indicador respeta su rango (puntaje 0–100, eficiencia 0–5, mejora −100–100, persistencia ≥ 1, riesgo 0–1) y su origen (Nivel 1 o Nivel 2) | §25.4 | CHECK `ck_indicadores_*` (8) | `IntegridadTest::testIndicadorDeNivel1RequiereActividadYRango` |
| N2 | Un perfil por estudiante y período; el período es válido | RF-10 | UNIQUE `uq_perfiles_usuario_periodo` + CHECK `ck_perfiles_periodo` | Demostrado en E-BD-011 (perfil repetido y período invertido rechazados) |
| N3 | Hay al menos 8 reglas, con código único, condición en JSON válido y versión ≥ 1 | §25.4, Tabla 5 obj. 5 | UNIQUE `uq_reglas_codigo` + CHECK `ck_reglas_condicion`, `ck_reglas_sugerencia`, `ck_reglas_version` | `EsquemaTest::testCatalogosSemilla` |
| N4 | De cada recomendación se puede rastrear qué regla (y qué versión) la generó y con qué datos | RF-12 (H20) | Tabla `recomendacion_regla` (FK + `version_regla` + CHECK `ck_recomendacion_regla_valores`) | `MotorAnalisisApiTest` (API, E-APP-008) |
| N5 | El sistema sugiere y el docente decide; una decisión por recomendación, que no se modifica | **D-6** | Tabla `decisiones_recomendacion`: UNIQUE `uq_decisiones_recomendacion`, FK a recomendación, actividad y docente; PRIV: `atlas_app` sin UPDATE/DELETE | `PrivilegiosTest::testAppNoModificaLasDecisionesDelDocente`, `MotorAnalisisApiTest::testElSistemaRecomiendaYElDocenteDecide` |
| N6 | El análisis grupal se calcula en la aplicación; la base guarda el historial con rangos y período válidos | RF-18, **D-4** | CHECK `ck_analisis_grupal_rangos`, `ck_analisis_grupal_periodo`; 0 procedimientos; PRIV: solo INSERT | `AnalisisGrupalTest::testLaBaseNoTieneProcedimientosDeCalculo`, `testAppAgregaAnalisisGrupalPeroNoLoAltera` |
| N7 | El agrupamiento (ML) tiene k entre 2 y 10 y silueta entre −1 y 1; el servicio de análisis no lee datos personales | RF-19, RNF-14 | CHECK `ck_agrupamientos_*`; PRIV: `atlas_analysis` sin acceso a nombres ni correos | `PrivilegiosTest::testAnalysisNoLeeNombresNiCorreos`, `testAnalysisSoloInsertaEnAnalisis` |

## 6. Auditoría y protección de los datos (RF-15, RNF-01, RNF-14)

| # | Regla de negocio | Origen | Cómo la garantiza la base | Prueba |
| --- | --- | --- | --- | --- |
| C1 | La auditoría no se modifica ni se borra, **ni siquiera como root** | RF-15 (H23) | TRG `trg_auditoria_sin_update`, `trg_auditoria_sin_delete` + PRIV: `atlas_app` solo INSERT | `AuditoriaTest::testAuditoriaNoSeModificaNiBorraNiSiquieraComoRoot`, `PrivilegiosTest::testAppNoPuedeAlterarNiBorrarAuditoria` |
| C2 | El detalle de auditoría y lo enviado al LLM se guardan como JSON válido | RF-15, RF-20 | Columnas de tipo JSON (MySQL rechaza un texto que no es JSON) + CHECK `ck_auditoria_detalle`, `ck_conversaciones_contexto` | Demostrado en E-BD-011 (JSON inválido rechazado) |
| C3 | La aplicación no puede cambiar la estructura de la base (una inyección SQL no podría borrar tablas) | §27.5 | PRIV: `atlas_app` sin DROP, ALTER, CREATE ni GRANT | `PrivilegiosTest::testAppNoPuedeCambiarEstructuraNiBorrarUsuarios` |
| C4 | Los reportes solo ven vistas, sin correo ni hash | Tabla 21, RNF-14 | PRIV: `atlas_read` solo SELECT sobre las 5 vistas | `PrivilegiosTest::testReadSoloVeVistas`, `EsquemaTest::testNingunaVistaExponeCorreoNiHash` |
| C5 | El respaldo lee todo pero no puede modificar datos | Tabla 21, §28.5 | PRIV: `atlas_backup` SELECT, LOCK TABLES, SHOW VIEW, TRIGGER; solo INSERT en `registro_respaldos` | `PrivilegiosTest::testBackupLeeTodoPeroNoEscribeDatos` |
| C6 | La administración total solo desde dentro del servidor | §27.5, Tabla 21 | `atlas_admin` existe solo `@localhost`; el resto solo desde la subred interna de los contenedores | `PrivilegiosTest::testAdminSoloDesdeDentroDelContenedor` |
| C7 | Toda relación tiene clave foránea y todas las tablas son InnoDB | Tabla 20, §27.4 | 48 FK; motor InnoDB | `EsquemaTest::testCadaColumnaTerminadaEnIdTieneClaveForanea`, `testTodasLasTablasSonInnoDbParaIntegridadReferencial` |

## Resumen

- **47 reglas.** 45 las garantiza la base, con **38 CHECK, 48 FK, 22 claves únicas, 13 triggers que solo rechazan** y los privilegios de 5 usuarios. Dos las garantiza la aplicación (A12 y P3), porque dependen de cuándo se publica o de un cálculo.
- 40 tienen una prueba automática contra un MySQL 8.0 real (E-BD-007: 58/58, y para A12 y N4 las pruebas de API, E-APP-008). P4 se verifica sobre datos representativos (E-BD-008). Las 6 restantes (U8, A9, R6, R8, N2, C2) no tienen una prueba automática propia: se **demuestran** en E-BD-011 provocando la violación y mostrando el rechazo de MySQL.
- [E-BD-011](../evidencias/G/E-BD-011-rechazos.txt) muestra, con el error real de MySQL, que las operaciones no autorizadas y los datos inválidos se rechazan (privilegios, restricciones y triggers).
