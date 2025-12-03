#!/usr/bin/perl
sub procesador {
    my $sdateline;
    my $line;
    my @archivo_salida;
    my @salida_log;
    my $abbrev;
    my $salida_final;
    @archivo_salida = logtail($archivo,$registro);
    foreach $line (@archivo_salida) {
            $abbrev = substr ($line, 0, 3);
            if ($abbrev eq "Mon") {
                $sdateline = $line;
            } elsif ($abbrev eq "Tue") {
                $sdateline = $line;
            } elsif ($abbrev eq "Wed") {
                $sdateline = $line;
            } elsif ($abbrev eq "Thu") {
                $sdateline = $line;
            } elsif ($abbrev eq "Fri") {
                $sdateline = $line;
            } elsif ($abbrev eq "Sat") {
                $sdateline = $line;
            } elsif ($abbrev eq "Sun") {
                $sdateline = $line;
            } else {
		$line =~ s/\n//g;
		$data = $line;
            }
	$sdateline =~ s/\n//g;	
	if(length($data)>0) {
	    if(var_not_null($patron)) {
		if($data =~ m/$patron/) {
		    $salida_final .= $sdateline." ".$data."\n";
		}
	    } else {
		$salida_final .= $sdateline." ".$data."\n";
	    }
	}
	undef $abbrev;
	undef $data;
    }
    return $salida_final;
}

1;
