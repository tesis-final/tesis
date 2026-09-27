# ATLAS-DOCKER-USER-INICIO — no editar a mano: lo genera 05-firewall.sh
# -----------------------------------------------------------------------------
# Docker publica 80/443 de atlas-web con DNAT, y ese tráfico va por FORWARD,
# no por INPUT: las reglas de UFW no lo ven (riesgo R-01). La cadena
# DOCKER-USER es el punto que Docker reserva para filtrar antes que él.
# Acá se repite el filtro de la Tabla 44 para el servicio web (DEC-05, CT-04):
#   443 solo desde VLAN 10, 20, 30 y VPN docentes (reglas 1 y 9); el resto, log + drop.
# Solo se filtra lo que entra por la interfaz física ({{IFACE}}); el tráfico que
# sale de los contenedores (p. ej. atlas-analysis → API del LLM, regla 7) no se toca.
# -----------------------------------------------------------------------------
*filter
:DOCKER-USER - [0:0]
-A DOCKER-USER -m conntrack --ctstate RELATED,ESTABLISHED -j RETURN
-A DOCKER-USER ! -i {{IFACE}} -j RETURN
-A DOCKER-USER -i {{IFACE}} -s {{RED_ADMIN}} -p tcp -m conntrack --ctorigdstport 443 --ctdir ORIGINAL -j RETURN
-A DOCKER-USER -i {{IFACE}} -s {{RED_DOCENTES}} -p tcp -m conntrack --ctorigdstport 443 --ctdir ORIGINAL -j RETURN
-A DOCKER-USER -i {{IFACE}} -s {{RED_ESTUDIANTES}} -p tcp -m conntrack --ctorigdstport 443 --ctdir ORIGINAL -j RETURN
-A DOCKER-USER -i {{IFACE}} -s {{RED_VPN_DOCENTES}} -p tcp -m conntrack --ctorigdstport 443 --ctdir ORIGINAL -j RETURN
-A DOCKER-USER -i {{IFACE}} -m limit --limit 5/min --limit-burst 10 -j LOG --log-prefix "[ATLAS DOCKER-USER DROP] "
-A DOCKER-USER -i {{IFACE}} -j DROP
COMMIT
# ATLAS-DOCKER-USER-FIN
