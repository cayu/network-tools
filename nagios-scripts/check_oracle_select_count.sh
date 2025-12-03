#!/bin/bash
# Sergio Cayuqueo <cayu@cayu.com.ar>
# http://cayu.com.ar
# Script para chequear un SELECT COUNT de una tabla en Oracle con un determinado timestamp
CONTEO=`echo -e "set head off\nset pagesize 0\nSELECT COUNT(DATA) FROM APPREG.DATA WHERE DATA = TO_DATE(SYSDATE,'DD/MM/YY');" |  sqlplus -S "/ as sysdba" | awk '/^[ 0-9\.\t ]+$/ {print int($1)}'`
LIMITE=5

if [[ "$CONTEO" -ge "$LIMITE" ]]
then
  echo "CRITICAL - Hay $CONTEO registros";
  exit 2;
else
  echo "OK - Hay $CONTEO registros";
  exit 0;
fi
