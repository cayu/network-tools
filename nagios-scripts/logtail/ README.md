Filtrador de LOGS
==================

### Actualmente: EN DESARROLLO

Fecha de inicio 5 de Enero de 2009

### Monitor de LOGS

### STATUS: Desarrollo

Script en perl para leer archivos de log y en caso de encontrar coincidencias con una expresión regular enviar por mail las lineas filtradas con los mensajes de log.
A su vez guarda el estado de lectura de los logs, o sea cuantas lineas de el log leyo para no tener que releer todo el log de nuevo cada vez que quiere acceder a los datos y no mostrar mensajes repetidos.

Aquí se detallan algunas de las características:

  * Totalmente escrito en perl, debería funcionar en win, lin y aix.
  * Envío por correo conectándose a un smtp (perl)
  * Log con todas las operaciones realizadas (falta definir formato)
  * Íntegramente configurable desde un archivo de conf.
  * Extendible por medio de plugins
    * Parser de Archivos Alert Log de Oracle
    * Parser de Archivos auth.log de SSH

### TODO

Cuando encuentra lineas de log repetidas que deben ser enviadas por correo, debería reemplazar las repetidas por una leyenda parecida a “La ultima linea se repitió N veces.”
Dependencias
Al momento de desarrollar la aplicacion se utilizaron las siguientes versiones. 
  * Perl 5.8.8
  * Debian Etch 4.0
  * Modulos de Perl
  * Config::IniFiles
  * File::Basename
  * Net::SMTP

### Configuracion

La configuracion del paquete se realiza por medio de un archivo de configuracion general, donde se establecen diferentes directivas.

``` ini
[general]
; directorio con los archivos de configuracion para cada servidor
servidores_dir  = servidores
; directorio con los archivos de logs del monitor
registros_dir   = registros
; registros de lectura de los logs, cuanto se proceso, para saber cuanto falta
offsets_dir     = offsets
; directorio donde encontrar los plugins
plugins_dir     = plugins
; servidor smtp ip y puerto
smtp_server     = 10.1.1.76:25
; prefijo para el asunto de los mails
mail_prefix     = [LogMonitor]

Archivo individual de configuracion de cada servidor
[configuracion]
; yes | no
activo  = yes
; registros activos que se revisan
;registros = messages,apache,daemon,auth,oracle
registros = auth-ssh

[messages]
mail    = cayu@cayu.com.ar
archivo = /var/log/messages
patron  = sergio
etiqueta= MESSAGES

[auth-ssh]
mail    = cayu@cayu.com.ar
archivo = /var/log/auth.log
procesador = ssh.pl
etiqueta= AUTH
; formato del email
formato_mail    = html

[oracle-alert-t24]
mail    = cayu@cayu.com.ar
archivo = /var/log/alert_OT2P1N1.log
procesador = oracle_alert.pl
patron  = ALTER DATABASE
etiqueta= ORACLE

[oradriver]
mail    = cayu@cayu.com.ar
archivo = /var/log/ORAdriver.log.1
etiqueta= ORADRIVER

[apache]
mail    = cayu@cayu.com.ar
archivo = /var/log/apache2/access.log.1
patron  = ico
etiqueta= APACHE

[daemon]
mail    = cayu@cayu.com.ar
archivo = /var/log/daemon.log
patron  = failed
etiqueta= DAEMON
```

La idea es configurar uno por servidor para su ejecucion local por medio de CRON, y que esta configuracion este desplegada por RSYNC para una mas rapida configuracion, con los cual modificamos los archivos en el servidor central y se repliegan por todos los servidores de la red.
Ademas se desarrollo la posibilidad de agregar plugins para el procesamiento individual de los archivos de logs combinandolo con la logica de logtail.
Notas
Actualmente en desarrollo, proximamente documentacion final del proyecto.
Para el desarrollo del plugin para chequear los archivos logs de auth de ssh use como referencia http://www.governmentsecurity.org/forum/index.php?showtopic=17795

``` pl
#!/usr/bin/perl

# /var/log/messages parser coded by tgo
# http://www.anomalous-security.org

use warnings;

open(F,"/var/log/messages") or die($!);

my %ips;

while(<F>)
{
 if ($_ =~ /(\d+\.\d+\.\d+\.\d+)/)
 {
 $ip = $1; 
 
 if ($_ =~ /Accepted/)
 {
 $action = "accepted";
 } 
 elsif($_ =~ /Failed password/)
 {
 $action = "failed"; 
 }
 else
 {
 next;
 }

 if (defined($ips{$ip}{$action}))
 {
 $ips{$ip}{$action} = $ips{$ip}{$action} + 1;
 }
 else
 {
 $ips{$ip}{$action} = 1;
 } 
 }
}

close(F);

for my $ip ( keys %ips )
{
 $ips{$ip}{'accepted'} = 0 unless (defined($ips{$ip}{'accepted'}));
 $ips{$ip}{'failed'} = 0 unless (defined($ips{$ip}{'failed'}));

 $total = $ips{$ip}{'accepted'} + $ips{$ip}{'failed'};

 print "------- Report for $ip -----------\n";
 print "Total Entries: " . $total . "\n";
 print "Accepted Logins: " . $ips{$ip}{'accepted'} . "\n";
 print "Failed Logins: " . $ips{$ip}{'failed'} . "\n";
}
```

Ejemplo de salida de ejecución :

```
------- Report for 60.28.27.14 -----------
Total Entries: 41
Accepted Logins: 0
Failed Logins: 41
------- Report for 210.56.192.70 -----------
Total Entries: 1261
Accepted Logins: 0
Failed Logins: 1261
------- Report for 202.201.5.139 -----------
Total Entries: 19
Accepted Logins: 0
Failed Logins: 19
```
