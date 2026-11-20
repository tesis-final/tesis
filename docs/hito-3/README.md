# Hito 3 · Proyecto consolidado y documentado

Equipo Error404 · ATLAS · entrega: viernes 20/11/2026 · estado al 20/11/2026

## Qué se entrega

| Entregable | Dónde |
|---|---|
| Documento integrador V3.1 en Word (editable, APA 7), con los resultados del laboratorio | [`ATLAS_Documento_integrador_V3.1.docx`](ATLAS_Documento_integrador_V3.1.docx) |
| Documento integrador V3.1 en un único PDF (cuerpo + Anexo E con el informe de Redes del Hito 2) | [`ATLAS_Documento_integrador_V3.1.pdf`](ATLAS_Documento_integrador_V3.1.pdf) |
| Capturas del laboratorio (19 y 20/11/2026) | [`capturas/`](capturas/) |
| Versión anterior, V3.0 del 12/11 (solo desarrollo) | `ATLAS_Documento_integrador_V3.0.*` |
| Plan de Redes paso a paso para el laboratorio (R-0 a R-12) | [`plan-redes-laboratorio.md`](plan-redes-laboratorio.md) |
| Fuente del documento (se regenera con un comando) | [`documento/`](documento/) |

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

## Laboratorio (jornada del 19/11/2026)

| Paso del plan | Estado | Resultado |
|---|---|---|
| R-8 circuito completo | Ejecutado | Docente crea y publica, estudiante resuelve desde la VLAN 30, docente ve indicadores; prueba 7 con registro ATLAS-R12 |
| R-9 base de datos | Ejecutado | seguir_intento OK; restaurar_intento 13/13; metricas 6 PASS, 0 FAIL |
| R-10 respaldo de la VM | Ejecutado | vzdump en 2 min; restauración en 81 s; en la copia sin red, atlas-web se reinicia |
| R-11 verificaciones | Ejecutado con FAIL | srv01 86 PASS / 31 FAIL (pasos 8 a 14 sin correr); DC 63 PASS / 5 FAIL (probable script viejo); firewall con reglas de la VPN |
| R-0 a R-7, R-12 | No ejecutado o sin evidencia | Siguen en el plan |

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
