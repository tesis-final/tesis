# Fase 1 — Auditoría de la especificación ATLAS V2.2

| Campo | Valor |
| --- | --- |
| Fuente única | [`docs/especificacion/TC4-Error404-ATLAS-V2.2.pdf`](../especificacion/TC4-Error404-ATLAS-V2.2.pdf) (123 págs., V2.2 del 18/09/2026) |
| Fecha de la auditoría | 26/09/2026 |
| Estado | **Aprobada** el 26/09/2026 (todas las recomendaciones aceptadas). Decisiones en [fase-02/01-registro-decisiones](../fase-02-arquitectura/01-registro-decisiones.md). No se implementó nada. |
| Regla vigente | **Siempre manda el PDF**; el prompt solo define el método de trabajo (indicado por el usuario el 26/09/2026) |
| Siguiente paso | Tus respuestas a [J.1](J-informacion-requerida.md#j1-decisiones-que-necesito) → Fase 2 |

## Contenido

| Parte | Documento |
| --- | --- |
| A | [Auditoría completa de la especificación](A-auditoria-especificacion.md): estructura, tablas, estado declarado, anexos |
| B | [Inventario de requisitos](B-inventario-requisitos.md): 201 requisitos trazados, todos en PENDIENTE |
| C | [Arquitectura identificada](C-arquitectura.md) |
| D | [Infraestructura identificada](D-infraestructura.md) |
| E | [Diseño de red identificado](E-diseno-red.md) |
| F | [Dependencias entre componentes](F-dependencias.md) |
| G | [Discrepancias y contradicciones](G-discrepancias.md) |
| H | [Riesgos técnicos](H-riesgos.md) |
| I | [Plan de implementación por fases](I-plan-fases.md) |
| J | [Información que necesito](J-informacion-requerida.md) |

## Convenciones

- **Citas**: §sección, Tabla N o H-N, p. N (numeración impresa del PDF).
- **Estados**: en esta fase todo está en PENDIENTE. Más adelante se usarán DISEÑADO → CONFIGURADO → EJECUTADO → VERIFICADO, y las pruebas llevarán PASS / FAIL / NO EJECUTADA.
- **PROPUESTA**: algo que no está en el PDF. No se aplica sin aprobación.
- **IDs**:

| Prefijo | Qué identifica |
| --- | --- |
| OBJ, RF, RNF, ARQ, ANA, BD, LNX, WIN, RED, FW, VPN, MON, P, DOC, FUN | Requisitos |
| DISC | Contradicciones del PDF |
| AMB | Ambigüedades y vacíos |
| PR | Diferencias entre el prompt y el PDF |
| ED | Observaciones editoriales |
| DEP | Dependencias |
| R | Riesgos |
| D | Decisiones pendientes |

## Resumen de hallazgos

| Métrica | Cantidad |
| --- | --- |
| Requisitos inventariados | 201 |
| Contradicciones internas del PDF | 24 |
| Ambigüedades y vacíos | 30 |
| Diferencias prompt ↔ PDF | 6 (resueltas: manda el PDF) |
| Riesgos técnicos | 27 |
| Decisiones que necesito | 1 regla de desempate + 22 decisiones + 2 definiciones (J.1) |

### Hallazgos críticos (bloquean la implementación)

1. **Las "ocho reglas documentadas" del motor no están en el PDF** (Tabla 5 las exige; ninguna sección las enumera). → AMB-01
2. **Servidor web**: Apache en cinco lugares, Nginx en la Tabla 15 y en la estructura Docker. → DISC-01
3. **MySQL**: contenedor (Tabla 15) contra servicio systemd con `bind-address 127.0.0.1` (Tabla 22), que impediría que los otros contenedores se conecten. → DISC-02
4. **WireGuard**: "sobre el servidor Linux" (§30.4) contra terminación en atlas-fw01 (Tabla 42, Figura 1, §30.1). → DISC-03
5. **Firewall con estado entre VLAN**: por la topología, el tráfico entre VLAN lo enruta atlas-rt01 y nunca pasa por fw01; las ACL del router no tienen estado. → DISC-04
6. **UFW contradice las reglas de red**: tal como está escrito, P-07 (Samba desde VLAN 20) y P-13 (VPN docente) fallarían. → DISC-06
7. **Permisos POSIX**: con `/srv/atlas` en 750, los servicios no pueden entrar a sus propios directorios; la Tabla 27 y §28.3 no coinciden. → DISC-07
8. **RPO de 24 h incumplible** si se pierde el servidor: los incrementales quedan solo en local. → DISC-10
9. **Docker saltea UFW** en los puertos publicados. → R-01
10. **MySQL 8.0 está fuera de soporte** desde abril de 2026. → R-02

## Método

- Texto de las 123 páginas extraído con dos herramientas; 61 tablas revisadas con sus columnas.
- Páginas con imagen revisadas visualmente: Figura 1, árbol de OU, matriz y Anexo A.
- Referencias cruzadas contrastadas.
- Dos supuestos verificados contra paquetes reales de Ubuntu 24.04. Uno quedó descartado: TCP Wrappers sí funciona en Ubuntu 24.04.
