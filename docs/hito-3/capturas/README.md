# Capturas del laboratorio (19 y 20/11/2026)

Lo que muestra cada captura. Están citadas en la V3.1 del documento integrador (Anexo K, Tabla K2).
Cuentas del laboratorio: Coordinación ITI (coordinacion@atlas.local), Juan Fernandez (docente,
juanfernandez1@atlas.local), Matias Perez (estudiante, matiasperez1@atlas.local). Grupos: «Docentes» y
«Grupo 1», año 2026, Instituto Tecnológico de Informática. Navegador: Edge en cliente-doc, ATLAS en
https://172.16.40.10 (aviso «No seguro»: el cliente todavía no confía en ATLAS-CA).

| Archivo | Evidencia | Qué se ve |
|---|---|---|
| H3-49-app-ingreso.png | E-APP-014 | Pantalla de ingreso (19:57) |
| H3-50-app-coordinacion-grupos.png | E-APP-014 | Grupos «Docentes» y «Grupo 1» con sus integrantes |
| H3-51-app-docente-inicio.png | E-APP-014 | Inicio del docente, tema claro |
| H3-52-app-editor.png | E-APP-014 | Editor: «Actividad de prueba 2», habilidad Cálculo |
| H3-53-app-aviso-motivo.png | E-APP-014 | ATLAS no publica sin opción correcta y dice por qué |
| H3-54-app-publicada.png | E-APP-014 | «Actividad publicada.» e historial BORRADOR → PUBLICADA |
| H3-55-cliente-vlan30.png | E-RED-016 | cliente-doc con 172.16.30.100 |
| H3-56-cliente-445-vlan30.png | E-RED-016 | 445 de srv01 desde la VLAN 30: False |
| H3-57-router-registro-445.png | E-RED-016 | ATLAS-R12 en router-lab, DPT=445 |
| H3-58-app-estudiante-inicio.png | E-APP-014 | Inicio del estudiante |
| H3-61-app-estudiante-resultado.png | E-APP-014 | Resultado 100/100, tiempo total y activo 3 s |
| H3-62-app-docente-grupo.png | E-APP-014 | Análisis del grupo |
| H3-63-app-docente-estudiante.png | E-APP-014 | Perfil del estudiante |
| H3-64-app-docente-por-que.png | E-APP-014 | Fundamento de una recomendación (R01) |
| H3-65-app-docente-consultas.png | E-APP-014 | Consulta guiada por habilidad |
| H3-66-app-docente-reportes.png | E-APP-014 | Reporte de intentos |
| H3-67-app-celular.png | E-APP-014 | Ingreso en iPhone SE (375 px) |
| H3-68-app-tema-oscuro.png | E-APP-014 | Inicio del docente, tema oscuro |
| H3-69-app-auditoria.png | E-APP-014 | Auditoría: 78 registros |
| H3-70-srv01-seguir-intento.png | E-BD-019 | seguir_intento.sh: RESULTADO OK |
| H3-71-srv01-restaurar-intento.png | E-BD-020 | restaurar_intento.sh: 13 de 13 |
| H3-72-srv01-metricas.png | E-BD-021 | metricas.sh: 6 PASS, 0 FAIL, 5 informativas |
| H3-73a-proxmox-vzdump.png | E-BD-015 | vzdump de la VM 130 |
| H3-73b-proxmox-restauracion.png | E-BD-015 | Restauración como VM 930: TASK OK |
| H3-73c-vm930-docker-ps.png | E-BD-015 | docker ps en la VM 930 (atlas-web en Restarting) |
| H3-74a-srv01-verificar.png | E-LNX-006 | verificar.sh: 86 PASS, 31 FAIL |
| H3-74b-dc-verificar.png | E-WIN-005 | verificar-dc01.ps1: 63 PASS, 5 FAIL |
| H3-74c-router-nft.png | E-RED-017 | nft list ruleset con las reglas de wg0 |


### Segunda jornada (20/11/2026): DC, VPN y Zabbix

| Archivo | Evidencia | Qué se ve |
|---|---|---|
| H3-03-proxmox-iso-repo.png | E-WIN-006 | CD regenerado con el MSI del agente de Zabbix |
| H3-05-dc-scripts-copiados.png | E-WIN-006 | Scripts 10 a 14 copiados a C:\ATLAS |
| H3-23-dc-retencion.png | E-WIN-006 / INC-18 | Tarea instalada y error de la simulación con la carpeta vacía |
| H3-24-dc-tarea-programada.png | E-WIN-006 | Tarea «ATLAS - Retencion de respaldos», diaria 05:00 |
| H3-26-srv01-instalar-14.png | E-RED-015 | Paso 14 y verificación: 93 PASS · 24 FAIL |
| H3-27-srv01-zabbix-contenedores.png | E-RED-015 | Contenedores de Zabbix; interfaz solo en 127.0.0.1:8080 |
| H3-28-dc-agente-zabbix.png | E-WIN-006 | Agente con firma válida, 10050 solo desde 172.16.40.10 |
| H3-29-srv01-atlas-ctl-monitoreo.png | E-RED-015 | Resultado OK; disco de srv01 al 99,1 % |
| H3-30 a H3-35 | E-RED-015 | Hosts, últimos datos, web, alerta abierta y resuelta, SLA 89,7 % |
| H3-36 a H3-44, H3-47 | E-RED-008a/b/c | Alta del par, ruta, túnel activo, pruebas 15 y 16, wg show, sin NAT, estado |
| H3-45, H3-46 | E-RED-014 | Prueba 14: rc=28 y ATLAS-R12 desde ens19 |
| H3-74d-dc-verificar-nuevo.png | E-WIN-005 | Verificador del DC: 73 PASS · 0 FAIL |
| H3-74e-srv01-verificar-monitoreo.png | E-RED-015 | monitoreo y firewall: 23 PASS · 0 FAIL |
| H3-75-srv01-disco-ampliado.png | INC-19 | Limpieza de Docker y volumen de 14 a 28 GB: disco al 42 %, salud ok |
| H3-74f-dc-verificar-despues-disco.png | E-WIN-005 | DC otra vez: 73 PASS · 0 FAIL |
| H3-74g-srv01-verificar-despues-disco.png | E-RED-015 | srv01 otra vez: 23 PASS · 0 FAIL |

No se tomaron: H3-01, H3-02, H3-04, H3-06 a H3-22, H3-25, H3-48, H3-59 y H3-60. Tampoco llegaron H3-23b ni la H3-74-a de la segunda jornada.
