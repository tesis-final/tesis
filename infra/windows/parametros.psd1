# =============================================================================
# ATLAS — parámetros de atlas-dc01 (Fase 7). SIN CONTRASEÑAS: las que hacen
# falta se piden en pantalla (Read-Host -AsSecureString) o se generan al azar.
# Cada valor indica de dónde sale en el PDF.
# =============================================================================
@{
    # --- Servidor (Tabla 31, Tabla 40) ---
    NombreEquipo      = 'atlas-dc01'
    IP                = '172.16.40.20'
    Prefijo           = 24
    Gateway           = '172.16.40.1'          # Tabla 38 (VLAN 40)
    ZonaHoraria       = 'Montevideo Standard Time'
    # Interfaz de red: vacío = la primera interfaz física conectada.
    Interfaz          = ''

    # --- Dominio (§29.1) ---
    Dominio           = 'atlas.local'
    NetBIOS           = 'ATLAS'
    DN                = 'DC=atlas,DC=local'

    # --- Cuentas por defecto (Tabla 32) ---
    # Nuevo nombre de la cuenta Administrator (queda solo para emergencias).
    NombreAdministrador = 'atlas.emergencia'

    # --- DNS (§29.4) ---
    # Reenviadores: PENDIENTE (J.2). Vacío = se usan las sugerencias de raíz; el
    # DC puede consultar DNS hacia Internet por la regla 7 de la Tabla 44.
    Reenviadores      = @()
    ServidorLinux     = @{ Nombre = 'atlas-srv01'; IP = '172.16.40.10' }   # Tabla 40

    # --- DHCP (Tabla 34) ---
    Ambitos = @(
        @{ Nombre = 'VLAN 10 - Administracion'; Red = '172.16.10.0'; Inicio = '172.16.10.100'; Fin = '172.16.10.200'; Gateway = '172.16.10.1' }
        @{ Nombre = 'VLAN 20 - Docentes';       Red = '172.16.20.0'; Inicio = '172.16.20.100'; Fin = '172.16.20.200'; Gateway = '172.16.20.1' }
        @{ Nombre = 'VLAN 30 - Estudiantes';    Red = '172.16.30.0'; Inicio = '172.16.30.100'; Fin = '172.16.30.250'; Gateway = '172.16.30.1' }
    )
    DuracionConcesion = '8.00:00:00'

    # --- Redes de origen (Tabla 38, Tabla 44) ---
    RedesUsuarios     = @('172.16.10.0/24', '172.16.20.0/24', '172.16.30.0/24')
    RedServidores     = '172.16.40.0/24'
    RedGestion        = '172.16.50.0/24'
    # IP del router en cada VLAN: origen del reenvío DHCP (regla 4).
    IPsRouter         = @('172.16.10.1', '172.16.20.1', '172.16.30.1', '172.16.40.1')

    # --- Rango RPC dinámico (DEC-17) ---
    RpcInicio         = 49152
    RpcCantidad       = 16384

    # --- Recursos compartidos (DEC-08, CT-09, CT-10) ---
    CarpetaBase       = 'C:\ATLAS'
    UnidadEstudiantes = 'S'      # \\atlas-dc01\estudiantes
    UnidadDocentes    = 'T'      # \\atlas-srv01\docentes

    # --- Autoridad certificadora (DEC-20) ---
    NombreCA          = 'ATLAS-CA'
    AniosCA           = 10
}
