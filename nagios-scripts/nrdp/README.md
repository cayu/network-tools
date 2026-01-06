
# nagioscorepassivecheck.inc.php (Versión Modificada: Direct Pipe)

Este archivo es una **versión modificada (fork)** del plugin original de NRDP (`nagioscorepassivecheck`) distribuido por Nagios Enterprises.

Esta modificación altera fundamentalmente la arquitectura de entrega de resultados pasivos al núcleo de Nagios Core, migrando de un sistema basado en archivos temporales en disco a una escritura directa en la memoria (Named Pipe).

---

## ⚡ Diferencias Clave con el Original

La principal diferencia radica en la reescritura de la función `nrdp_write_check_output_to_cmd`.

| Característica | Plugin Original (Legacy) | Plugin Modificado (Actual) |
| :--- | :--- | :--- |
| **Mecanismo de Entrega** | **Spool de Archivos en Disco** | **Tubería de Comandos (Named Pipe)** |
| **Operaciones de E/S** | **Altas.** Crea 2 archivos por chequeo (`.ok` y data), requiere lectura y borrado posterior por parte del proceso *reaper*. | **Mínimas.** Escribe directamente en el *handle* del archivo especial `nagios.cmd` en memoria. |
| **Latencia** | **Variable/Alta.** Depende del ciclo de ejecución del *reaper* de Nagios (ej. cada 10-15s). | **Cero (Real-time).** El núcleo de Nagios recibe y procesa el comando al instante. |
| **Fiabilidad** | **Baja.** Propensa a fallos por permisos de archivo (usuario Apache vs Nagios), bloqueos y condiciones de carrera. | **Robusta.** Operación atómica de escritura en el *pipe* gestionada por el sistema operativo. |
| **Formato de Salida** | Vulnerable a errores de escape en saltos de línea (`\\n\n`). | Formateado específicamente para el protocolo de comandos externos de Nagios. |

---

## 🛠️ Detalles Técnicos de la Modificación

### 1. Migración a `nagios.cmd` (Pipe)
En la versión original, el script utilizaba `tempnam()` para crear archivos físicos en el directorio `checkresults`. Esto causaba problemas frecuentes donde el usuario web (`apache`) creaba archivos que el usuario `nagios` no podía borrar debido a máscaras de permisos o grupos incorrectos.

**La nueva implementación:**
1. Obtiene la ruta de la tubería de comandos (`command_file`) directamente desde `nagios.cfg`.
2. Construye el comando externo estándar en una sola línea:
```text
[<timestamp>] PROCESS_SERVICE_CHECK_RESULT;<host>;<service>;<state>;<output>
```
3. Abre el *pipe* en modo escritura (`w`) y envía la cadena, evitando el sistema de archivos por completo.

### 2. Corrección de Formato (Parsing)
Se solucionó un error crítico en el código original donde los saltos de línea se escapaban incorrectamente (`\n` seguido de `\n`) al final de la salida. Esto provocaba que el analizador interno de Nagios descartara resultados válidos silenciosamente. La versión modificada asegura que la salida sea limpia y cumpla con la especificación de comandos externos.

### 3. Preservación de NDO
La función `nrdp_write_check_output_to_ndo`, utilizada para escribir resultados históricos directamente a la base de datos (común en instalaciones de Nagios XI para backfilling), se ha mantenido **intacta**. Esto asegura la compatibilidad con arquitecturas que dependen de ella para importar datos antiguos.

---

## ✅ Cuándo usar esta versión

Esta versión modificada es **altamente recomendada** para:

* **Entornos de Alto Rendimiento:** Instalaciones que reciben miles de chequeos pasivos por minuto.
* **Problemas de Permisos:** Sistemas donde se experimentan errores de "stale files" en `/var/spool/checkresults` o el log de Nagios muestra 0 resultados cosechados.
* **Instalaciones Modernas:** Nagios Core 4.x optimizado para el uso del archivo de comandos externos.

### Requisitos Previos
Para que esta modificación funcione, asegúrese de que la siguiente directiva esté habilitada en su archivo `nagios.cfg`:

```properties
check_external_commands=1
```

