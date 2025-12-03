#!/usr/bin/perl
sub procesador {
    my $salida;
    my @archivo_salida;
    @archivo_salida = logtail($archivo,$registro);
    my %ips;
    if (var_not_null(@archivo_salida))  {
	foreach (@archivo_salida) {
	    if ($_ =~ /(\d+\.\d+\.\d+\.\d+)/) {
		$ip = $1;
		if ($_ =~ /Accepted/) {
	    	    $action = "accepted";
		} elsif($_ =~ /Failed password/) {
		    $action = "failed";
		} elsif($_ =~ /Invalid/) {
		    $action = "invalid";
		} else {
		    next;
		}
		if (defined($ips{$ip}{$action})) {
		    $ips{$ip}{$action} = $ips{$ip}{$action} + 1;
		} else {
		    $ips{$ip}{$action} = 1;
		}
	    }
	}
    }
    if (var_not_null(%ips)) {
	$salida .= "<html>
	<head>
	</head>
	<body>
	<div align='center'>
	<H1><font face=Verdana,Arial align='center'>Informe de LOGINS por SSH</font></H1><br>
	<table border='0' width='60%' align='center'>";
    }
    for my $ip ( keys %ips ) {
	$ips{$ip}{'accepted'} = 0 unless (defined($ips{$ip}{'accepted'}));
	$ips{$ip}{'failed'} = 0 unless (defined($ips{$ip}{'failed'}));
	$ips{$ip}{'invalid'} = 0 unless (defined($ips{$ip}{'invalid'}));
	$total = $ips{$ip}{'accepted'} + $ips{$ip}{'failed'} + $ips{$ip}{'invalid'};
	$salida .= "
	<tr bgcolor='#FFDD00'>
	    <td>Reporte para</td><td>$ip</td>
	</tr>
	<tr bgcolor='#3D98FF'>
	    <td>Total de entradas:</td><td>$total</td>
	</tr>
	<tr bgcolor='#00FF00'>
	    <td>Logins Aceptados:</td>
	    <td>$ips{$ip}{'accepted'}</td>
	</tr>
	<tr bgcolor='#FF0000'>
	    <td>Logins Fallidos:</td>
	    <td>$ips{$ip}{'failed'}</td>
	</tr><tr bgcolor='#FF0000'>
	    <td>Usuario invalido:</td>
	    <td>$ips{$ip}{'invalid'}</td>
	</tr>
	<tr colspan=2><td colspan=2><hr></td></tr>";
    }
    if (var_not_null(%ips)) {    
    	$salida .= "
	</table></div>
	</body>
	</html>";
    }
    return $salida;
}
1;
