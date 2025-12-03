#!/usr/bin/php -q
# Sergio Cayuqueo <cayu@cayu.com.ar>
# http://cayu.com.ar
<?php
$lista_imagenes = shell_exec("si_lsimage --verbose|grep Image");
$lista_imagenes = preg_split("/[\n]+/",$lista_imagenes);
$fecha_actual = date('Y.m.d');
foreach($lista_imagenes as $imagen) {
    if(strlen($imagen)>0) {
	if(@!$i) {
	    $i=1;
	}
	$imagen = preg_split("/[\s]+/",$imagen);
	$imagenes[$i]['nombre'] = $imagen[2];
	$imagenes[$i]['actualizada'] = $imagen[4];
	$imagenes[$i]['ip'] = $imagen[8];
	if($imagen[4] == $fecha_actual) {
	    $imagenes[$i]['estado'] = "ok" ;
	} else {
	    $imagenes[$i]['estado'] = "critical" ;
            $critical=1;
	}
	$i++;
    }
}
 
if(@$critical) {
    $head = "CRITICAL - Hubo un desfasaje en una o mas imagenes\n";
    $exit = 2;
} else {
    $head = "OK - Todas las imagenes actualizadas a la fecha\n";
    $exit = 0;
}
print $head;
foreach($imagenes as $imagen) {
    if(strlen($imagen['nombre'])<9) {
	$tab = "\t\t";
    } else {
	$tab = "\t";
    }
    if($imagen['estado'] == "ok") {
	print "OK - ".$imagen['nombre']." ".$tab.$imagen['ip']."\n";
    } else {
        print "CRITICAL - ".$imagen['nombre']."   ".$tab.$imagen['ip']." \t actualizado a : ".$imagen['actualizada']."\n";
    }
}
exit($exit);
?>
