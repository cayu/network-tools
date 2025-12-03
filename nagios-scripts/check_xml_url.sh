#!/bin/bash
# Sergio Cayuqueo <cayu@cayu.com.ar>
# http://cayu.com.ar

# Script para chequear sintaxis XML de un WebService

wget -q -O - --user-agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10.8; rv:21.0) Gecko/20100101 Firefox/21.0" $1 | xmlstarlet val - 1>/dev/null 2>/dev/null
EXIT_STATUS=$?

if [[ $EXIT_STATUS -eq "0" ]]; then
    echo "OK - La sintaxtis es correcta : $EXIT_STATUS"
fi

if [[ $EXIT_STATUS -ne "0" ]]; then
    echo "CRITICAL - La sintaxtis no es correcta : $EXIT_STATUS"
fi
