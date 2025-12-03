#!/bin/bash
# Sergio Cayuqueo <cayu@cayu.com.ar>
# http://cayu.com.ar
# Script para chequear el database_status en Oracle

DATABASE_STATUS=`echo -e "set head off\nset pagesize 0\nSELECT status, database_status FROM v\\$instance;" |  sqlplus -S "/ as sysdba"| cut -f1`

case "$DATABASE_STATUS" in
        MOUNTED)
            start
            echo "CRITICAL - Los tablespaces de la base de datos estan $DATABASE_STATUS -" `date '+DATE: %m/%d/%y TIME:%H:%M:%S'`
            exit 2;
            ;;
        OPEN)
            echo "OK - Los tablespaces de la base de datos estan $DATABASE_STATUS -" `date '+DATE: %m/%d/%y TIME:%H:%M:%S'`
            exit 1;
            ;;
        *)
            echo "CRITICAL - Hay algun error con la base de datos $DATABASE_STATUS -" `date '+DATE: %m/%d/%y TIME:%H:%M:%S'`
            exit 2;
esac
