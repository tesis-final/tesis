# Alta disponibilidad: replicación y conmutación ante fallos

Devolución de Base de Datos (Hito 2): *"recomiendo estudiar una alternativa de alta disponibilidad mediante replicación y conmutación ante fallos. Será relevante explicar qué problemas resuelve y cómo complementa la estrategia de respaldo, considerando que no la sustituye."*

Además de explicarla, la **probamos**: [E-BD-012](../evidencias/G/E-BD-012-replicacion-y-conmutacion.txt), con la herramienta `atlas/database/tools/demostrar_replicacion.sh` (dos MySQL 8.0 reales en Docker, con el esquema y los datos representativos de ATLAS).

## 1. Qué es, en dos líneas

- **Replicación:** un segundo servidor MySQL (la *réplica*) recibe del servidor principal (el *primario*) cada cambio que se confirma y lo aplica. Tiene en todo momento una copia viva de la base.
- **Conmutación ante fallos (*failover*):** si el primario se cae, la réplica pasa a ser el primario y la aplicación se conecta a ella. El servicio vuelve sin restaurar nada.

## 2. Qué problema resuelve, y cuál no

| Situación | ¿La resuelve la replicación? | ¿La resuelve el respaldo? |
| --- | --- | --- |
| Se rompe el disco o el servidor de la base | **Sí**, en segundos o minutos: se promueve la réplica | Sí, pero en horas: hay que instalar, restaurar el completo y aplicar el binlog |
| Hay que apagar el servidor por mantenimiento (actualizaciones) | **Sí**: se pasa a la réplica, se hace el mantenimiento y se vuelve | No (habría que cortar el servicio) |
| Alguien borra datos por error (`DELETE` sin `WHERE`, un script mal hecho) | **No**: el borrado se replica en menos de un segundo (E-BD-012 §3: 0,7 s) | **Sí**: se restaura hasta el instante anterior al error (completo + binlog, E-BD-005/009) |
| Ransomware o un ataque que cifra o altera datos | **No**: la réplica recibe los mismos cambios | **Sí**, si el respaldo está fuera de su alcance (copia en el servidor Windows, Tabla 29) |
| Se necesita un dato de hace dos semanas | **No**: la réplica solo tiene el presente | **Sí**: retención de 4 semanas (Tabla 29) |
| Se corrompe una tabla por un error lógico de la aplicación | **No**: se replica | **Sí** |

**La replicación protege la disponibilidad (que el servicio siga andando). El respaldo protege los datos (poder volver atrás).** Son complementarias: la replicación baja el tiempo de recuperación ante fallas físicas, y el respaldo sigue siendo la única defensa ante errores humanos, ataques y pérdidas que se replican.

## 3. Lo que se midió (E-BD-012, Docker de desarrollo)

| Prueba | Resultado |
| --- | --- |
| Copia fiel | Después de instalar ATLAS y cargar 9.000 intentos y 88.745 respuestas en el primario, la réplica tenía exactamente lo mismo: huella de `CHECKSUM TABLE` de 7 tablas igual, 13 triggers, `Seconds_Behind_Source: 0` |
| La réplica no se puede tocar | `DELETE` en la réplica → `ERROR 1290 … super-read-only`: ni root escribe en ella; solo recibe lo que viene del primario |
| Un error humano se replica | Un borrado de 9.895 filas en el primario llegó a la réplica en **0,7 s** |
| Caída del primario | Se mató el primario (`docker kill`) mientras se escribía. **RPO: 0** (los 16 intentos confirmados estaban en la réplica). **RTO: 0,97 s** hasta la primera escritura en la réplica promovida |

**Límites honestos de la medición:**
- Los dos MySQL estaban en la misma PC, con una red sin demoras. En dos servidores reales la réplica va un poco más atrás.
- La promoción la hizo el script al instante. Con una persona siguiendo el procedimiento son **minutos**, no milisegundos.
- Con replicación **asíncrona** (la que se probó), el RPO fue 0, pero **no está garantizado**: si el primario cae justo después de confirmar una transacción y antes de enviarla, esa transacción se pierde. Para que el RPO sea siempre 0 se usa replicación **semisincrónica** (ver §4).

## 4. Alternativas que se evaluaron

| Alternativa | Cómo funciona | A favor | En contra | ¿Para ATLAS? |
| --- | --- | --- | --- | --- |
| **A. Primario + réplica asíncrona, conmutación manual** | El primario envía los cambios; si cae, un operador promueve la réplica siguiendo un procedimiento | Simple, sin servidores extra, nativo de MySQL; es la que se probó | Puede perder lo último confirmado; necesita a una persona | **Sí (recomendada para el prototipo)** |
| **B. Igual que A, pero semisincrónica** | El primario no confirma una transacción hasta que la réplica la recibió | RPO 0 garantizado | Cada escritura espera a la réplica (más lenta si la red es mala) | **Sí, como mejora**: es un parámetro más sobre A |
| **C. InnoDB Cluster (Group Replication + MySQL Router)** | 3 servidores que votan; el Router redirige solo a la aplicación | Conmutación automática, sin operador | Necesita 3 servidores y más administración | Para producción con muchos usuarios; excede el prototipo |
| **D. Alta disponibilidad de la VM (Proxmox HA)** | Si cae un nodo físico, la VM arranca en otro | No cambia MySQL | Necesita al menos 3 nodos Proxmox y almacenamiento compartido | Fuera del alcance del laboratorio |

## 5. Propuesta para ATLAS

1. **atlas-db2 (réplica) en otro servidor** de la VLAN 40, con replicación por GTID desde atlas-db: semisincrónica si la red lo permite (alternativa B), si no asíncrona (A). La réplica en `super_read_only` y con su propio usuario de replicación (solo `REPLICATION SLAVE`), siguiendo el criterio de privilegio mínimo de la Tabla 21.
2. **Conmutación manual con procedimiento escrito:** confirmar que el primario no vuelve (para evitar dos primarios a la vez, *split-brain*), promover la réplica (`STOP REPLICA; RESET REPLICA ALL; SET GLOBAL super_read_only = OFF`), cambiar `ATLAS_DB_HOST` de la aplicación al nuevo primario (o el registro DNS `atlas-db` en el DNS del dominio, atlas-dc01) y reiniciar `atlas-php`. Cuando se arregla el viejo primario, pasa a ser la réplica del nuevo.
3. **El respaldo no cambia y se refuerza:** el completo semanal y el incremental diario (Tabla 29) se pueden tomar **desde la réplica**, para no cargar el primario. La copia fuera del servidor (Windows, regla 3-2-1) sigue siendo obligatoria, porque es lo único que protege contra errores humanos y ataques.
4. **Qué cambia en los objetivos:** ante una **falla física**, el RTO baja de horas (restaurar, E-BD-005) a minutos (promover la réplica). Ante un **error humano**, el RTO y el RPO siguen siendo los del respaldo (E-BD-005/009: RPO 0 con el binlog).

## 6. Qué falta para llevarlo al laboratorio

- Una segunda VM para atlas-db2 (en Proxmox, VLAN 40) y las reglas de firewall para el puerto 3306 **solo entre atlas-db y atlas-db2**.
- Probar el procedimiento de conmutación con una persona, medir el tiempo real y guardarlo como evidencia.
- Decidir entre asíncrona y semisincrónica según la latencia de la red del laboratorio.
