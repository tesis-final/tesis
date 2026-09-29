#!/usr/bin/env python3
"""ATLAS · Fase 8 — Revisor automático de las configuraciones de Cisco.

Lee atlas-sw01.txt, atlas-rt01-base.txt y atlas-fw01-maqueta.txt y compara cada
línea relevante contra las tablas del PDF (Tabla 38, Tabla 41, p. 66–67) y las
decisiones. No reemplaza a Packet Tracer: detecta errores de tipeo y de diseño
ANTES de pegar la configuración (un puerto en la VLAN equivocada, un
helper-address que falta, una contraseña escrita en claro).

Uso: python3 infra/red/pruebas/revisar_configuraciones.py
"""
from __future__ import annotations

import ipaddress
import os
import re
import sys
from pathlib import Path

DIR = Path(os.environ.get("ATLAS_CONFIG_DIR", Path(__file__).resolve().parent.parent / "packet-tracer"))

# --- Lo que dice el PDF ------------------------------------------------------
VLANS = {10: "Administracion", 20: "Docentes", 30: "Estudiantes", 40: "Servidores", 50: "Gestion", 999: "Sin_uso_nativa"}
GATEWAYS = {v: f"172.16.{v}.1" for v in (10, 20, 30, 40, 50)}  # Tabla 38
CON_DHCP = {10, 20, 30}  # Tabla 34: VLAN 40 y 50 con IP fijas
DC = "172.16.40.20"  # Tabla 40
PUERTOS = {  # Tabla 41: puerto -> (vlan, habilitado)
    **{f"FastEthernet0/{i}": (10, True) for i in range(1, 5)},
    **{f"FastEthernet0/{i}": (20, True) for i in range(5, 11)},
    **{f"FastEthernet0/{i}": (30, True) for i in range(11, 21)},
    "FastEthernet0/21": (40, True),
    "FastEthernet0/22": (40, True),
    "FastEthernet0/23": (50, True),
    "FastEthernet0/24": (999, False),
    "GigabitEthernet0/2": (999, False),
}
TRONCAL = "GigabitEthernet0/1"
GESTION = ipaddress.ip_network("172.16.50.0/24")

resultados: list[tuple[bool, str]] = []


def chk(desc: str, cond: bool) -> None:
    resultados.append((bool(cond), desc))


def expandir(nombre: str) -> list[str]:
    """'range FastEthernet0/1 - 4' -> [FastEthernet0/1, ..., /4]."""
    m = re.match(r"range (\S+?)(\d+)\s*-\s*(\d+)$", nombre)
    if not m:
        return [nombre]
    base, a, b = m.group(1), int(m.group(2)), int(m.group(3))
    return [f"{base}{i}" for i in range(a, b + 1)]


def leer(archivo: str) -> tuple[list[str], dict[str, list[str]]]:
    """Devuelve las líneas globales y un diccionario interfaz -> líneas del bloque."""
    texto = (DIR / archivo).read_text(encoding="utf-8")
    lineas = [l.rstrip() for l in texto.splitlines() if l.strip() and not l.lstrip().startswith("!")]
    interfaces: dict[str, list[str]] = {}
    actual: list[str] | None = None
    for l in lineas:
        if l.startswith("interface "):
            # Un "interface range" comparte el mismo bloque de líneas entre todos sus puertos.
            actual = []
            for n in expandir(l[len("interface "):].strip()):
                interfaces[n] = actual
            continue
        if not l.startswith(" "):
            actual = None
        elif actual is not None:
            actual.append(l.strip())
    return lineas, interfaces


def bloque(lineas: list[str], cabecera: str) -> list[str]:
    """Líneas indentadas que siguen a una cabecera global (p. ej. 'line vty 0 15')."""
    salida, dentro = [], False
    for l in lineas:
        if l.startswith(cabecera):
            dentro = True
            continue
        if dentro and not l.startswith(" "):
            break
        if dentro:
            salida.append(l.strip())
    return salida


def secretos(lineas: list[str], archivo: str) -> None:
    for l in lineas:
        m = re.search(r"\b(secret|password)\s+(?:\d\s+)?(\S+)", l)
        if m and not l.strip().startswith(("no ", "security passwords", "service password")):
            chk(f"{archivo}: sin contraseñas en claro ('{l.strip()[:40]}…' usa un marcador <…>)", m.group(2).startswith("<"))
    chk(f"{archivo}: no usa 'enable password' (solo 'enable secret')", not any(l.startswith("enable password") for l in lineas))


def gestion_ssh(lineas: list[str], archivo: str) -> None:
    vty = bloque(lineas, "line vty 0 15")
    chk(f"{archivo}: VTY solo acepta SSH (transport input ssh)", "transport input ssh" in vty)
    chk(f"{archivo}: VTY con login local", "login local" in vty)
    acl = next((l.split()[-2] for l in vty if l.startswith("access-class")), None)
    chk(f"{archivo}: VTY con access-class", acl is not None)
    permitidas = bloque(lineas, f"ip access-list standard {acl}") if acl else []
    chk(f"{archivo}: {acl} permite solo 172.16.50.0/24 y niega el resto con log",
        permitidas == ["permit 172.16.50.0 0.0.0.255", "deny any log"])
    chk(f"{archivo}: SSH versión 2", "ip ssh version 2" in lineas)
    chk(f"{archivo}: sin servidor HTTP", "no ip http server" in lineas and "no ip http secure-server" in lineas)
    chk(f"{archivo}: service password-encryption", "service password-encryption" in lineas)


def revisar_switch() -> str:
    a = "atlas-sw01.txt"
    lineas, itf = leer(a)
    for v, nombre in VLANS.items():
        i = lineas.index(f"vlan {v}") if f"vlan {v}" in lineas else -1
        chk(f"{a}: VLAN {v} '{nombre}' creada (Tabla 38 / p. 66)", i >= 0 and lineas[i + 1].strip() == f"name {nombre}")
    for puerto, (vlan, habilitado) in PUERTOS.items():
        b = itf.get(puerto, [])
        ok = ("switchport mode access" in b and f"switchport access vlan {vlan}" in b
              and "switchport nonegotiate" in b and (("no shutdown" in b) if habilitado else ("shutdown" in b)))
        if habilitado:
            ok = ok and "spanning-tree portfast" in b
        chk(f"{a}: {puerto} acceso VLAN {vlan} {'habilitado' if habilitado else 'APAGADO'} (Tabla 41)", ok)
    t = itf.get(TRONCAL, [])
    chk(f"{a}: {TRONCAL} troncal 802.1Q", "switchport mode trunk" in t)
    chk(f"{a}: {TRONCAL} VLAN nativa 999 (p. 66)", "switchport trunk native vlan 999" in t)
    chk(f"{a}: {TRONCAL} permite solo 10,20,30,40,50 (Tabla 41)", "switchport trunk allowed vlan 10,20,30,40,50" in t)
    chk(f"{a}: {TRONCAL} sin DTP (nonegotiate)", "switchport nonegotiate" in t)
    v1 = itf.get("Vlan1", [])
    chk(f"{a}: VLAN 1 sin IP y apagada", "no ip address" in v1 and "shutdown" in v1)
    ip50 = next((l.split()[2] for l in itf.get("Vlan50", []) if l.startswith("ip address")), None)
    chk(f"{a}: gestión en VLAN 50 con IP de 172.16.50.0/24 (p. 67)", ip50 is not None and ipaddress.ip_address(ip50) in GESTION)
    chk(f"{a}: gateway del switch = router en VLAN 50", "ip default-gateway 172.16.50.1" in lineas)
    gestion_ssh(lineas, a)
    secretos(lineas, a)
    return ip50 or ""


def revisar_router() -> str:
    a = "atlas-rt01-base.txt"
    lineas, itf = leer(a)
    chk(f"{a}: Gi0/0 (troncal) sin IP y encendida", "no ip address" in itf.get("GigabitEthernet0/0", []) and "no shutdown" in itf.get("GigabitEthernet0/0", []))
    for v, gw in GATEWAYS.items():
        b = itf.get(f"GigabitEthernet0/0.{v}", [])
        chk(f"{a}: Gi0/0.{v} dot1Q {v} con {gw}/24 (Tabla 38)", f"encapsulation dot1Q {v}" in b and f"ip address {gw} 255.255.255.0" in b)
        helper = f"ip helper-address {DC}" in b
        if v in CON_DHCP:
            chk(f"{a}: Gi0/0.{v} reenvía DHCP a {DC} (§29.4, regla 4)", helper)
        else:
            chk(f"{a}: Gi0/0.{v} SIN reenvío DHCP (IP fijas, Tabla 34)", not helper and not any("helper" in l for l in b))
    n = itf.get("GigabitEthernet0/0.999", [])
    chk(f"{a}: Gi0/0.999 nativa sin IP (coincide con el switch, p. 66)", "encapsulation dot1Q 999 native" in n and not any(l.startswith("ip address") for l in n))
    g1 = itf.get("GigabitEthernet0/1", [])
    ip_t = next((l.split()[2:4] for l in g1 if l.startswith("ip address")), None)
    chk(f"{a}: Gi0/1 (tránsito hacia fw01) con IP /30", ip_t is not None and ip_t[1] == "255.255.255.252")
    chk(f"{a}: Gi0/2 sin uso y apagada", "shutdown" in itf.get("GigabitEthernet0/2", []))
    ruta = next((l.split()[-1] for l in lineas if l.startswith("ip route 0.0.0.0 0.0.0.0")), None)
    chk(f"{a}: ruta por defecto hacia fw01", ruta is not None)
    if ip_t and ruta:
        red = ipaddress.ip_interface(f"{ip_t[0]}/{ip_t[1]}").network
        chk(f"{a}: el siguiente salto {ruta} está en la red de tránsito {red}", ipaddress.ip_address(ruta) in red and ruta != ip_t[0])
    chk(f"{a}: ruta a la VPN 10.8.0.0/24 por fw01 (Tabla 45)", f"ip route 10.8.0.0 255.255.255.0 {ruta}" in lineas)
    chk(f"{a}: hora desde atlas-dc01 (Tabla 35)", f"ntp server {DC}" in lineas)
    chk(f"{a}: registro local en búfer (DEC-R8)", any(l.startswith("logging buffered") for l in lineas))
    gestion_ssh(lineas, a)
    secretos(lineas, a)
    return ip_t[0] if ip_t else ""


def revisar_maqueta(ip_rt01: str) -> None:
    a = "atlas-fw01-maqueta.txt"
    lineas, itf = leer(a)
    g0 = next((l.split()[2:4] for l in itf.get("GigabitEthernet0/0", []) if l.startswith("ip address")), None)
    chk(f"{a}: la maqueta está en la misma red de tránsito que rt01",
        g0 is not None and ipaddress.ip_address(ip_rt01) in ipaddress.ip_interface(f"{g0[0]}/{g0[1]}").network)
    chk(f"{a}: vuelve a 172.16.0.0/16 por rt01", f"ip route 172.16.0.0 255.255.0.0 {ip_rt01}" in lineas)
    g1 = next((l.split()[2] for l in itf.get("GigabitEthernet0/1", []) if l.startswith("ip address")), "")
    chk(f"{a}: la 'Internet simulada' usa direcciones de documentación (RFC 5737)",
        ipaddress.ip_address(g1) in ipaddress.ip_network("203.0.113.0/24") if g1 else False)


def main() -> int:
    ip_sw = revisar_switch()
    ip_rt = revisar_router()
    revisar_maqueta(ip_rt)
    chk("coherencia: la IP de gestión del switch no choca con el gateway de VLAN 50", ip_sw != "172.16.50.1")
    for ok, desc in resultados:
        print(f"  {'PASS' if ok else 'FAIL'}  {desc}")
    fallas = sum(1 for ok, _ in resultados if not ok)
    print(f"\nResultado: {len(resultados) - fallas} PASS · {fallas} FAIL")
    return 1 if fallas else 0


if __name__ == "__main__":
    sys.exit(main())
