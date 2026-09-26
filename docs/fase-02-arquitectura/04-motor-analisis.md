# 04 — Motor de análisis (BORRADOR para aprobación)

> **Estado: PROPUESTA (DEC-23).** El PDF define los 4 indicadores (§25.4) y exige al menos 8 reglas (Tabla 5), pero no las enumera. Todo lo marcado como PROPUESTA sale de este documento, no del PDF. **No se programa hasta que el equipo lo apruebe o lo corrija.** Los umbrales numéricos son valores iniciales editables por el administrador (§27.3), no verdades pedagógicas.

## 1. Indicadores del Nivel 1

Se calculan por estudiante y actividad al finalizar cada intento (H18: "tras cada actividad finalizada").

| Indicador | Definición | Fuente |
| --- | --- | --- |
| Puntaje | `correctas / total_preguntas × 100` del intento | PDF §25.4 (literal) |
| Mejora | `puntaje(último intento finalizado) − puntaje(primer intento finalizado)`; vale 0 si hay un solo intento | PDF §25.4 (literal) |
| Persistencia | Cantidad de intentos (finalizados y abandonados) hasta el último intento finalizado | PDF §25.4 (literal) |
| Eficiencia | **PROPUESTA**: `(puntaje / 100) ÷ (duración del estudiante / duración media del grupo en esa actividad)`, con la media calculada sobre intentos finalizados del mismo grupo. Si el grupo tiene menos de 3 intentos finalizados en la actividad, queda **sin valor** (no se inventa una media). Se acota a [0, 5] | PDF §25.4 da la idea ("relaciona el puntaje con el tiempo respecto al promedio del grupo"); la fórmula es propuesta |

Lectura de la eficiencia: vale 1,0 cuando el estudiante logra el 100 % en el tiempo medio del grupo. Sube si logra lo mismo en menos tiempo y baja si tarda más o acierta menos.

Cada fila de `indicadores` guarda `perfil_id`, `actividad_id`, `tipo`, `valor` y `calculado_en`. Para rastrearla (H18), se consultan los intentos de ese estudiante en esa actividad hasta `calculado_en`.

## 2. Las 8 reglas (PROPUESTA)

Solo usan los 4 indicadores, la categoría y el nivel de la actividad. Cada regla vive en `reglas_analisis` con su condición en JSON, editable por el administrador, y versionada.

| Código | Tipo | Condición (valores iniciales) | Recomendación al docente |
| --- | --- | --- | --- |
| R01 | RIESGO | Puntaje del último intento < 50 | Proponer otra actividad de la **misma categoría y nivel** para reforzar |
| R02 | AVANCE | Puntaje ≥ 85 **y** eficiencia ≥ 1,0 | Proponer una actividad del **nivel siguiente** en la misma categoría |
| R03 | REFUERZO | Puntaje ≥ 85 **y** eficiencia < 0,7 | Domina el contenido pero con lentitud: practicar en el **mismo nivel** para ganar fluidez |
| R04 | AVANCE | Mejora ≥ 20 **y** puntaje ≥ 70 | Aprende con la práctica: mantener la categoría y **subir de nivel** |
| R05 | RIESGO | Persistencia ≥ 3 **y** mejora ≤ 0 | Estancamiento: proponer el **nivel inferior** y sugerir intervención directa del docente |
| R06 | RECONOCIMIENTO | Persistencia ≥ 4 **y** puntaje final ≥ 70 | Tolera la dificultad y llega: reconocer el esfuerzo; continuar en el mismo nivel |
| R07 | RIESGO | Persistencia = 1 **y** puntaje < 50 | No reintenta tras un mal resultado: incentivar un nuevo intento |
| R08 | RIESGO | Puntaje medio < 50 en ≥ 2 actividades de la **misma categoría** en el período | Dificultad sostenida en esa categoría: priorizarla con el nivel inferior |

Funcionamiento:

- El motor evalúa todas las reglas activas.
- Una recomendación puede venir de más de una regla (`recomendacion_regla`, N:M).
- Cada recomendación guarda la regla, su versión y los **valores de entrada** usados. Eso permite responder "¿por qué ATLAS recomienda esto?" con **qué regla y con qué datos**.
- Es determinista: los mismos datos producen siempre el mismo resultado.

**Actividad sugerida**: se elige una actividad PUBLICADA en los grupos del estudiante, de la categoría y nivel que indica la regla, que el estudiante no haya finalizado. Si no existe, la recomendación queda como texto sin actividad asociada y se le avisa al docente que falta contenido.

## 3. Atención prioritaria (RF-18) (PROPUESTA)

- Un estudiante es **prioritario** en un período si disparó **al menos una regla de tipo RIESGO** (R01, R05, R07, R08).
- Se ordena por cantidad de reglas de riesgo y luego por la más reciente.
- Es 100 % explicable: se muestran las reglas y los datos que lo llevaron a esa lista.
- La señal de riesgo del ML (Nivel 2), cuando existe, se muestra **aparte**, rotulada como estimación estadística. No decide quién es prioritario.

Análisis grupal (RF-18), en este orden de pantalla:

1. Estudiantes prioritarios.
2. Preguntas con mayor proporción de error.
3. Promedio, mediana, mínimo y máximo.
4. Distribución por rangos de puntaje.
5. Agrupamientos del ML, si existen.

## 4. Nivel 2: aprendizaje automático (PROPUESTA de parámetros)

Variables (PDF §25.4, exactamente seis), por estudiante y período:

1. Puntaje promedio.
2. Tiempo relativo al grupo (media de duración propia / media del grupo).
3. Cantidad de intentos.
4. Variación entre intentos (desvío estándar del puntaje).
5. Actividades abandonadas.
6. Frecuencia de uso (días con actividad / días del período).

Se estandarizan antes de entrenar.

| Parámetro | Propuesta | Justificación |
| --- | --- | --- |
| Período | Mes calendario; recálculo semanal y a pedido del docente | RF-19: "se recalcula por período" |
| Condición de volumen (explícita) | Por grupo y período: **≥ 20 estudiantes con ≥ 5 intentos finalizados cada uno** (≥ 100 intentos) | El PDF dice que ML sobre 20 registros sería incorrecto; esto exige más de 100 |
| K-means | k entre 2 y 4, elegido por el mayor coeficiente de silueta; si la mejor silueta es < 0,25, **no se presentan agrupamientos** (no hay estructura) | Evita mostrar grupos artificiales |
| Regresión logística: etiqueta ("dificultad creciente") | y = 1 si, en la **siguiente** actividad finalizada del estudiante, el puntaje cae ≥ 15 puntos respecto de su promedio previo, **o** si abandona esa siguiente actividad; y = 0 en otro caso | Es observable en los datos y coincide con "señales de dificultad creciente" (§25.4) |
| Condición para entrenar la regresión | ≥ 100 ejemplos rotulados y cada clase ≥ 20 % de los ejemplos; validación cruzada de 5 particiones; se informa el AUC | Sin clases balanceadas mínimas, el modelo no se entrena |
| Presentación | "Señal estadística de riesgo: alta / media / baja", con la probabilidad y el aviso de que es una estimación, no un diagnóstico (§18) | — |

Si no se cumple la condición de volumen, la API responde `datos_insuficientes` con los números actuales (por ejemplo, "12 de 20 estudiantes con 5 intentos") y la interfaz lo muestra así.

## 5. Nivel 3: asistente (reglas de anonimización)

| Se envía al LLM | Nunca se envía |
| --- | --- |
| Tipo de consulta, seudónimos (E1..En, G1), nombre de la categoría, valores numéricos de indicadores, reglas disparadas (código y descripción), período | Nombres, apellidos, correos, cédulas, identificadores de la BD, nombre del grupo, nombre de la institución, texto libre de la pregunta sin sanitizar |

Test obligatorio: comparar el contenido saliente contra todos los nombres, apellidos y correos de la BD de prueba; cualquier coincidencia hace fallar el test.

## 6. Otros parámetros de comportamiento (PROPUESTA)

| Tema | Propuesta | Requisito |
| --- | --- | --- |
| Bloqueo de login en ATLAS | 3 fallos consecutivos por cuenta → bloqueo de **15 minutos** (el mismo tiempo que AD, Tabla 32); el contador se reinicia con un login correcto; todo auditado | RF-02 |
| Contraseñas de ATLAS | Mínimo 10 caracteres (igual que la política del dominio, Tabla 32) | RNF-01 |
| Pausa | La pestaña deja de estar visible, o pasan ≥ 60 s sin eventos → evento `PAUSA` con su duración al reanudar | RF-06 |
| Abandono | El estudiante sale sin finalizar (botón "salir"), o el intento queda ≥ 30 min sin eventos → estado `ABANDONADO`; el tiempo registrado llega hasta el último evento | RF-07, RF-08, RF-09 |
