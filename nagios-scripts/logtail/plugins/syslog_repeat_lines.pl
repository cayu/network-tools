#!/usr/bin/perl

sub count_unique {
    my @array = @_;
    my %count;
    my @salida_final;
    map { $count{$_}++ } @array;
    map { push(@salida_final," ${count{$_}} $_"); } sort keys(%count);
    return @salida_final
}

sub procesador {
    my @archivo_salida;
    my @salida_unique;
    @archivo_salida = logtail($archivo,$registro);
    my @salida;
    my $salida_final;

    foreach (@archivo_salida) { 
	$_ =~ s/^(\w{3})(\s|\s\s)(\d{1,2})(\s)(\d{1,2})(\:)(\d{1,2})(\:)(\d{1,2})(\s)($hostname)(\s)//g;
	$_ =~ s/^(.*)\[(.*)\]/$1/g;
	push(@salida,$_);
    }

    @salida_unique = count_unique(@salida);    
    $salida_final = join (' ', @salida_unique);
    return $salida_final;
}

1;
