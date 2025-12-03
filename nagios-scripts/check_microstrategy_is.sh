#!/bin/sh
# Sergio Cayuqueo <cayu@cayu.com.ar>
# http://cayu.com.ar

SALIDA_SSH=`ssh $1 -l monitoreo "sudo /msis/var/opt/MicroStrategy/bin/mstrctl -s IntelligenceServer gs" | grep state|  sed 's/<[^>]*[>]//g' | sed 's/\t//g' | sed 's/\n//g'`
if [ $SALIDA_SSH="running" ]
then
    echo "OK - Proceso MicroStrategy corriendo"
    exit 0;
else
    echo "CRITICAL - Hay un problema con el proceso MicroStrategy"
fi
