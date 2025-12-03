#!/usr/bin/perl
#use strict;
#use warnings;
use Config::IniFiles;
use File::Basename;
use Net::SMTP;
use constant TRUE => 1;
use constant FALSE => 0;

$configuracion 	 = Config::IniFiles->new( -file => "monitor.conf" );
$servidores_dir  = $configuracion->val('general', 'servidores_dir');
$offsets_dir  	 = $configuracion->val('general', 'offsets_dir');
$registros_dir	 = $configuracion->val('general', 'registros_dir');
$plugins_dir	 = $configuracion->val('general', 'plugins_dir');
$smtp_server  	 = $configuracion->val('general', 'smtp_server');
$mail_prefix  	 = $configuracion->val('general', 'mail_prefix');
$tipo_conf 	 = $configuracion->val('general', 'tipo_conf');
$hostname = `hostname`;
chomp($hostname);
sub set_servidor {
    if($tipo_conf eq "individual") {
	$servidor_archivo = $servidores_dir."/".$hostname.".serv";
	test_file($servidor_archivo,"Configuracion del servidor.");
	$servidor 		= Config::IniFiles->new( -file => $servidor_archivo );
	$servidor_nombre 	= $hostname ;
	$servidor_activo 	= $servidor->val('configuracion', 'activo');
	if($servidor_activo eq 'no') {
	    print "Servidor inactivo $servidor_nombre.\n";
	    exit();
	}
    } else {
	$servidor_archivo = $servidores_dir."/global.serv";
	test_file($servidor_archivo,"Configuracion global de servidores.");
	$servidor 		= Config::IniFiles->new( -file => $servidor_archivo );
	$servidor_nombre 	= $hostname ;
	$servidor_activo 	= $servidor->val('configuracion', 'activo');
    }
    $servidor_registros	= $servidor->val('configuracion', 'registros');
}

sub test_file {
    my $logfile = shift;
    my $msg	= shift;
    if (!var_not_null($logfile)) {
	print "No hay archivo a leer. $msg\n";
	exit();
    } elsif (! -f $logfile) {
        print "El archivo $logfile no puede ser leido. $msg\n";
	exit();
    }
}

# envia_mail ( destinos , asunto , remitente , mensaje )
sub envia_mail {
    # a quienes enviar
    my $destino   = shift;
    @destino=split(",",$destino);
    # asunto del mensaje
    my $asunto 	  = shift;
    # remitente del mensaje
    my $remitente = shift;
    # mensaje del correo
    my $mensaje   = shift;
    # formato del mensaje nada es 'solo texto' o html 'html'
    my $formato	  = $formato_mail;
    my $smtp 	  = Net::SMTP->new($smtp_server)|| die "Error al conectar al SMTP\n";
    $smtp->mail($remitente)|| die "Error en el remitente\n";
    $smtp->to(@destino)	   || die "Error en el destinatario $destino\n";
    $smtp->data();
    $smtp->datasend("From: $remitente\n");
    $smtp->datasend("To: $destino\n");    
    $smtp->datasend("Subject: $mail_prefix HOST: $servidor_nombre ETIQUETA: $asunto\n");
    $smtp->datasend("Content-Type: text/html; charset=us-ascii \n") if ($formato eq 'html'); 
    $smtp->datasend("\n");
    $smtp->datasend($mensaje);
    $smtp->dataend();
    $smtp->quit;
}

sub logtail {
    my $logfile = shift;
    my $registro= shift;
    my $size;
    test_file($logfile,"Analizador de Logs");
    $offsetfile = $offsets_dir . "/" . basename($logfile) . '-' . $registro . '.offset';
    unless (open(LOGFILE, $logfile)) {
	print "El archivo $logfile no puede ser leido.\n";
	exit();
    }
    my ($inode, $ino, $offset) = (0, 0, 0);
    unless (not $offsetfile) {
        if (open(OFFSET, $offsetfile)) {
    	    $_ = <OFFSET>;
    	    unless (! defined $_) {
       		chomp $_;
		$inode = $_;
		$_ = <OFFSET>;
	    unless (! defined $_) {
	        chomp $_;
	        $offset = $_;
		}
    	    }
	}
	unless ((undef,$ino,undef,undef,undef,undef,undef,$size) = stat $logfile) {
    	    return "No se puede obtener el tamaño del archivo $logfile.\n", $logfile;
	}
	if ($inode == $ino) {
#    	    exit 0 if $offset == $size; # short cut
    	    if ($offset > $size) {
        	$offset = 0;
        	return "***************\n";
        	return "*** WARNING ***: El archivo de log  $logfile es mas pequeño\n";
        	return "*************** de lo que estaba, puede haber sido manipulado.\n";
    	    }
	}
	if ($inode != $ino || $offset > $size) {
    	    $offset = 0;
	}
	seek(LOGFILE, $offset, 0);
    }
    while (<LOGFILE>) {
	push(@salida_log,$_);
    }
    $size = tell LOGFILE;
    close LOGFILE;
    unless (open(OFFSET, ">$offsetfile")) {
        return "El archivo $offsetfile no puede ser creado. Chequear los permisos.\n";
    }
    print OFFSET "$ino\n$size\n";
    close OFFSET;
    if(var_not_null(@salida_log)) {
	return @salida_log;
    }
}

sub AddSlashes {
    my $term = shift;
    $term =~ s/([\\\"\'\’\”\$])/\\$1/gi;
    return $term;
}

sub logger {
    my $logfile         = $registros_dir."/".$hostname.".log";
    my $message         = shift;
    my $server          = shift;
    my $extra           = shift;
    # borramos las lineas vacias
    $message =~ s/^\s$//g;
    if (!$message =~ m/^$/) {
        ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
        # fomateamos la fecha (8 -> 08, etc)
        $year   = ($year+1900);
        $mon    = sprintf("%02d", ($mon+1));
        $min    = sprintf("%02d", ($min+1));
        $mday   = sprintf("%02d", $mday);
        $sec    = sprintf("%02d", ($sec+1));
	$timestamp = "$year-$mon-$mday $hour:$min:$sec";
	# mensaje a loggear
        $linea_log = $timestamp." ".$message;
        open(LOGFILE,">>$logfile") or die("No se puede abrir el archivo de registro de acciones $logfile.");
        print LOGFILE "$linea_log";
        close(LOGFILE);
    }
}

sub egrep {
    my $salida = shift;
    my $patron = shift;
    my $egrep;
    $salida =~ s/\n//g;
    open(EGREP, "echo \"".AddSlashes($salida)."\" | egrep '$patron'|");
    while (defined($egrep = <EGREP>)) {
        push(@salida_final,$egrep);
        return $egrep;
    }
    close(EGREP);
}

sub var_not_null {
    my $variable=shift;
    if (defined($variable)) {
        if ($variable ne '') {
            if (length($variable)>0) {
                return TRUE;
            }
        }
    }
    return FALSE;
}

1;
