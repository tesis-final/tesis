# Hito 3 · Proyecto consolidado y documentado

Equipo Error404 · ATLAS · entrega: viernes 20/11/2026 · estado al 20/11/2026

## Qué se entrega

| Entregable | Dónde |
|---|---|
| Documento integrador V3.2 en Word (editable, APA 7), con los resultados del laboratorio | [`ATLAS_Documento_integrador_V3.2.docx`](ATLAS_Documento_integrador_V3.2.docx) |
| Documento integrador V3.2 en un único PDF (cuerpo + Anexo E con el informe de Redes del Hito 2) | [`ATLAS_Documento_integrador_V3.2.pdf`](ATLAS_Documento_integrador_V3.2.pdf) |
| Capturas del laboratorio (19 y 20/11/2026, dos jornadas) | [`capturas/`](capturas/) |
| Versiones anteriores: V3.0 (12/11, solo desarrollo) y V3.1 (20/11, primera jornada) | `ATLAS_Documento_integrador_V3.0.*` y `V3.1.*` |
| Plan de Redes paso a paso para el laboratorio (R-0 a R-12) | [`plan-redes-laboratorio.md`](plan-redes-laboratorio.md) |
| Fuente del documento (se regenera con un comando) | [`documento/`](documento/) |
| Hito 3 de Testing: cobertura, calidad y conclusiones (Word y PDF) | [`Hito3_Testing_ATLAS.docx`](Hito3_Testing_ATLAS.docx), [`Hito3_Testing_ATLAS.pdf`](Hito3_Testing_ATLAS.pdf) y [`testing/`](testing/) |

El documento se arma con `docs/hito-3/documento/armar-pdf.sh` (Node.js con `docx`, LibreOffice y
`pdfunite`). Los resultados que cita salen de `documento/resultados.js`, y cada uno apunta a un archivo
de `docs/evidencias/`. Los diagramas de arquitectura y topología se dibujan en `documento/diagramas/*.html`.

## Qué cambió en el repositorio para el Hito 3

| Área | Cambio | Evidencia (desarrollo) |
|---|---|---|
| Interfaz | Rediseño completo con el logotipo, tema claro/oscuro, responsivo y accesible; misma SPA en JavaScript y mismo contrato de API | E-APP-015 (29/29) y `B/capturas/hito3/` |
| Base de datos | Seguimiento de un intento de punta a punta, puntaje guardado contra calculado con rechazos de `atlas_app`, restauración por intento | E-BD-016, E-BD-017, E-BD-018 |
| Métricas | M1 a M16 con meta y forma de medirlas (`metricas.sh`, `medir.py`, `disponibilidad.sh`) | E-TST-007, 008 y 009 |
| Linux | Paso 13: respaldos automáticos con copia al DC; paso 14: monitoreo con Zabbix; `atlas-ctl respaldos` y `monitoreo` | probar-respaldos (17/17), E-RED-012, E-RED-013 (14/14), E-LNX-005 |
| Windows | `13-retencion-respaldos.ps1` y `14-agente-zabbix.ps1`; verificador con la Fase 12 | E-WIN-004 (52/52) |
| Redes | `05-vpn.sh` con los perfiles de la Tabla 45; pruebas de VPN en el gemelo del router | E-RED-011 (46/46) |
| Pruebas | Conjunto `monitoreo` en `probar-todo.sh` y en GitHub Actions | E-TST-010 |

## Laboratorio (jornadas del 19 y 20/11/2026)

| Paso del plan | Estado | Resultado |
|---|---|---|
| R-8 circuito completo | Ejecutado | Docente crea y publica, estudiante resuelve desde la VLAN 30, docente ve indicadores; prueba 7 con registro ATLAS-R12 |
| R-9 base de datos | Ejecutado | seguir_intento OK; restaurar_intento 13/13; metricas 6 PASS, 0 FAIL |
| R-10 respaldo de la VM | Ejecutado | vzdump en 2 min; restauración en 81 s; en la copia sin red, atlas-web se reinicia |
| R-2, R-5 (DC), R-6 | Ejecutado 20/11 | CD nuevo y scripts en el DC; retención instalada (INC-18 corregida); Zabbix con dos agentes, alerta probada y SLA |
| R-7 VPN | Ejecutado 20/11 | Pruebas 14, 15 y 16 aprobadas; VPN-09 sin NAT |
| R-11 verificaciones | Ejecutado | DC 73 PASS / 0 FAIL; srv01 93 PASS / 24 FAIL (pasos 8 a 13 sin correr); monitoreo y firewall 23/23 |
| R-3, R-4, R-5 (srv01), R-12 | No ejecutado | Siguen en el plan; además, liberar el disco de srv01 (INC-19) |

## Cómo repetir las pruebas

```bash
sudo ./probar-todo.sh                    # todas las que no necesitan el laboratorio
./probar-local.sh                        # ATLAS con datos de demostración
python3 atlas/tests/e2e/interfaz.py https://localhost <carpeta> <clave demo>
python3 atlas/tests/e2e/trazar_intento.py https://localhost <carpeta> <clave demo>
sudo atlas/database/tools/comparar_puntaje.sh
sudo atlas/database/tools/restaurar_intento.sh [intento]
sudo atlas/database/tools/metricas.sh
```

Si la red sale por un proxy con certificado propio: `CA_EXTRA=/ruta/ca.crt sudo -E ./probar-todo.sh`.
