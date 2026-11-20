# Capturas del laboratorio (19/11/2026) · notas para documentar

Lo que muestra cada captura recibida. Se usa para redactar la V3.1 del documento integrador.
Cuentas del laboratorio: Coordinación ITI (coordinacion@atlas.local), Juan Fernandez (docente,
juanfernandez1@atlas.local), Matias Perez (estudiante, matiasperez1@atlas.local). Grupos: «Docentes» y
«Grupo 1», año 2026, Instituto Tecnológico de Informática. Navegador: Edge en cliente-doc, ATLAS en
https://172.16.40.10 (aviso «No seguro»: el cliente todavía no confía en ATLAS-CA).

## Con archivo en esta carpeta

| Archivo | Hora | Qué se ve |
|---|---|---|
| H3-49-app-ingreso.png | 19:57 | Pantalla de ingreso con logotipo, panel «Ver el proceso, no solo el resultado», aviso de bloqueo tras tres intentos |
| H3-50-app-coordinacion-grupos.png | 19:59 | Coordinación → Grupos: «Docentes» (1 estudiante) y «Grupo 1» (1); miembros de Grupo 1: Juan Fernandez (Docente) y Matias Perez (Estudiante) |
| H3-51-app-docente-inicio.png | 20:00 | Docente, «Dónde intervenir hoy», tema claro: 1 grupo, 1 estudiante, 0 requieren atención; Grupo Docentes promedio 100, período 2026-11-01 a 2026-11-30 |
| H3-68-app-tema-oscuro.png | 20:00 | La misma pantalla en tema oscuro |
| H3-67-app-celular.png | 20:03 | Ingreso emulado en iPhone SE (375 × 667) con DevTools de Edge |

## Recibidas solo como vista previa (falta el archivo)

| N.º | Hora | Qué se ve |
|---|---|---|
| H3-52 editor | 20:07 | «Actividad de prueba 2»: ¿10 × 200?, habilidad Cálculo, opción B 2000 marcada correcta |
| H3-53 aviso con motivo | 20:11 | «Actividad de prueba 3» (¿100 ÷ 0?): aviso rojo de ATLAS «La actividad no cumple las condiciones para publicarse · Pregunta 1: Cada pregunta necesita exactamente 1 opción correcta», pregunta marcada en rojo |
| H3-54 publicada | 20:12 | Opción C «No se puede dividir entre 0» correcta; aviso «Actividad publicada.»; historial 20:10 Creación → BORRADOR, 20:12 BORRADOR → PUBLICADA (Juan Fernandez). Directo, sin aprobación (D-2) |
| H3-55 VLAN 30 | 20:15 | `ipconfig /release` y `/renew`: 172.16.30.100/24, puerta 172.16.30.1, sufijo atlas.local |
| H3-56 445 | 20:21 | `Test-NetConnection 172.16.40.10 -Port 445` desde 172.16.30.100: TcpTestSucceeded False |
| H3-57 registro router | 02:22–02:23 UTC (20/11) | router-lab: `ATLAS-R12 IN=ens18.30 OUT=ens18.40 SRC=172.16.30.100 DST=172.16.40.10 … DPT=445 SYN`, cinco intentos |
| H3-58 estudiante inicio | 20:26 | Matias Perez, «Mis actividades»: próxima «Actividad de prueba 3»; «Actividad de prueba» con último resultado 100/100 |
| H3-61 resultado | 20:27 | 100 de 100, 1 de 1 correctas, tiempo total 3 s, tiempo activo 3 s |
| H3-62 grupo | 20:32 | Grupo Docentes: atención prioritaria Matias Perez con R07 No reintento y R01 Puntaje bajo; ¿100 ÷ 0? 50 % de error (1 de 2); Cálculo 100 % (2 de 2), Adecuado; K-means: 0 de 20 estudiantes, no se agrupa |
| H3-63 estudiante | 20:33 | Perfil de Matias Perez: 2 actividades con datos, promedio 100, último 100, 3 recomendaciones; evolución 100 → 0 → 100 (12/11, 19/11, 19/11) |
| H3-64 ¿Por qué? | 20:34 | Recomendación de riesgo; fundamento R01 Puntaje bajo (versión 1), «puntaje del último intento menor a 50», datos usados puntaje = 0; falta contenido de esa categoría y nivel |
| H3-65 consultas | 20:36 | Consulta guiada: Grupo Docentes, Este mes, «¿Cómo va el grupo en cada habilidad?» → Cálculo 100 %, 0 de 1 por debajo del 50 % |
| H3-66 reportes | 20:37 | 3 intentos finalizados, promedio 66,7, tiempo activo medio 5 s; prueba 3: intentos 100 (3 s) y 0 (7 s); prueba (12/11) 100 (6 s) |
| H3-69 auditoría | 20:38 | 78 registros, 5 accesos denegados, 4 usuarios; login/logout, intentos.iniciar/finalizar desde 172.16.30.100, actividades.publicar #3 desde 172.16.20.100 |
| H3-71 seguir_intento | 23:39 | `vm 130 -- …/seguir_intento.sh`: intento 3, FINALIZADO, 3 s; 4 interacciones (INICIO, VER_PREGUNTA, SELECCION, FIN); un resultado 100.00; «OK · un único resultado y el puntaje guardado coincide con el recalculado» |
| H3-72 restaurar | 23:39 | restaurar_intento.sh: respaldo 165 ms (94 084 bytes), restauración 1004 ms, 13 de 13 comparaciones iguales, 9 tablas con el mismo conteo |
| H3-70 métricas | 23:40 | metricas.sh en srv01, MySQL 8.0.46: 6 PASS, 0 FAIL, 5 informativas; M10/M11 sin registros de respaldos |
| H3-73 vzdump | 23:45 | Respaldo de VM 130: 30 GiB en 124 s, archivo 5,17 GB, «Backup job finished successfully» |
| H3-73b restauración | 23:46–23:48 | Task viewer: VM 930 - Restore, 100 %, TASK OK; VM 930 arrancada 23:49 |
| docker ps (srv01) | ? | atlas-php, atlas-analysis y atlas-db arriba; **atlas-web «Restarting (1)»** (probablemente en la VM 930 restaurada, a confirmar) |
