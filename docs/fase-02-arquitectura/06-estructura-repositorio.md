# 06 — Estructura de repositorios

## Repositorio `SVinas73/tesis` (este)

```
tesis/
├── docs/
│   ├── especificacion/          ← PDF oficial (no se modifica)
│   ├── fase-01-auditoria/
│   ├── fase-02-arquitectura/
│   ├── fase-03-plan/            ← próximo
│   ├── manuales/                ← implementación de redes, operación, defensa oral
│   └── evidencias/{B,C,D,E,G}/  ← Anexos del PDF (Tabla 52); F lo produce el equipo
├── atlas/                       ← aplicación PHP, estructura literal de §26.2
│   ├── public/                  (index.php, css/, js/, assets/)
│   ├── app/{Core,Middleware,Controllers,Models,Services/Analysis,Repositories}/
│   ├── config/
│   ├── database/{migrations,seeds}/
│   ├── tests/
│   ├── docker/{php/Dockerfile, nginx/default.conf, mysql/init.sql}
│   ├── docker-compose.yml, .dockerignore, .env.example, README.md
├── infra/
│   ├── linux/        ← aprovisionamiento de atlas-srv01 (usuarios, ACL, sshd, UFW, DOCKER-USER, SSSD, Samba, chrony, rsyslog)
│   ├── backups/      ← completo, incremental, configuración, verificación, restauración, timers
│   ├── windows/      ← PowerShell de atlas-dc01 (AD DS, OU, grupos, GPO, DNS, DHCP, firewall, carpetas)
│   ├── network/
│   │   ├── cisco/    ← atlas-sw01.cfg, atlas-rt01.cfg (completos)
│   │   ├── packet-tracer/  ← .pkt
│   │   └── gns3/     ← guía y tabla de correspondencia de puertos
│   ├── firewall/     ← atlas-fw01: netplan, nftables.conf, sysctl
│   ├── vpn/          ← wg0.conf (plantilla sin claves), alta de pares, plantillas de cliente
│   ├── monitoring/   ← compose de Zabbix, plantillas, triggers
│   └── validation/   ← scripts de validación automática (servicios, puertos, DNS, DHCP, firewall, API, respaldos, permisos)
└── README.md
```

## Repositorio `SVinas73/atlas-analysis` (DEC-14; lo tiene que crear el usuario)

Estructura literal de §26.2:

```
atlas-analysis/
├── app/{main.py, features.py, models/{clustering.py, risk.py}, llm/{client.py, prompts.py}}
├── tests/
├── Dockerfile
├── requirements.txt
└── README.md
```

## Despliegue en atlas-srv01

- Se clonan ambos repositorios.
- `docker-compose.yml` de `atlas/` construye atlas-analysis desde la ruta del segundo clon (variable `ANALYSIS_BUILD_CONTEXT` en `atlas.conf`).
- Los archivos se copian a las rutas de §28.3 (ver 02-arquitectura-final, sección 3).

## Convenciones

| Tema | Convención |
| --- | --- |
| Código PHP | PSR-12 (Tabla 17) |
| Código Python | PEP 8 |
| Nombres | Dominio y BD en español (como el PDF); carpetas técnicas como §26.2 |
| Commits | Chicos, con mensaje claro (Tabla 17); una fase por PR |
| Secretos | Nunca en Git: `.env.example` y `infra/**/*.example` documentan las variables |
