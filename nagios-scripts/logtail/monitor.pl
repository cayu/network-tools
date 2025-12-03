#!/usr/bin/perl
# Script para parseo de datos de LOG
# Sergio Cayuqueo <cayu@cayu.com.ar>
# http://cayu.com.ar
# libreria fundamental
require 'monitor_lib.pl';
# inicializar variables y datos del servicio
set_servidor();
@registros = split(/,/,$servidor_registros);
foreach $registro (@registros) {
    test_file($servidor->val($registro,'archivo'));
    if($servidor->val($registro,'patron')) {
	$patron	= $servidor->val($registro,'patron');
    }
    $archivo 	= $servidor->val($registro,'archivo');
    $email   	= $servidor->val($registro,'mail');
    $etiqueta 	= $servidor->val($registro,'etiqueta');
    $procesador	= $servidor->val($registro,'procesador');
    $formato_mail = $servidor->val($registro,'formato_mail');
    if(!var_not_null($procesador)) {
        @salida_registro = logtail($archivo,$registro);
        foreach $salida (@salida_registro) {
            if(!var_not_null($procesador)) {
                if(!var_not_null($patron)) {
    		    $salida_procesada = egrep($salida,$patron);
	    	    push(@salida_final,$salida_procesada) if(var_not_null($salida_procesada));
		} else {
		    push(@salida_final,$salida)
		}
	    }
	}
	$salida_mail = join (' ', @salida_final);
    } elsif (var_not_null($procesador)) {
        require $plugins_dir."/".$procesador;
	$salida_mail = procesador();
    }
    if($salida_mail) {
	envia_mail($email, $etiqueta, $ENV{'USER'}."\@".$hostname, $salida_mail ) if(var_not_null($salida_mail));
	logger("$email,$etiqueta,$ENV{'USER'}\@$hostname\n" );
    } else {
	logger("$email,No se encontraron cambios en el log, no se envio mail,$ENV{'USER'}\@$hostname\n" );
    }
    undef @salida_final, $salida_mail, $patron, $etiqueta;
}
