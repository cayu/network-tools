GUÍA DE INSTALACIÓN Y SEGURIDAD
===============================

1. CONFIGURACIÓN INICIAL
   - Abra el archivo 'nrdp_config.json' con el Bloc de notas.
   - Edite "NRDPUrl", "Token", "User" y "Password" con sus credenciales reales.
   - Guarde los cambios.
   - ¡No necesita editar ningún archivo .ps1!

2. INSTALACIÓN
   - Mueva esta carpeta a una ruta segura, ej: C:\NRDP_Monitoreo\

3. SEGURIDAD (IMPORTANTE)
   - Haga clic derecho en 'nrdp_config.json' -> Propiedades -> Seguridad.
   - Elimine el acceso a "Usuarios".
   - Asegúrese de que SOLO "SYSTEM" y "Administradores" tengan permiso de lectura.
   - Esto evita que usuarios normales vean el Token.

4. AUTOMATIZACIÓN
   - Configure el Task Scheduler para ejecutar los scripts .ps1.
   - Asegúrese de que la tarea se ejecute como "SYSTEM" para que pueda leer el config.json protegido.

Sergio Cayuqueo <cayu@cayu.com.ar>
