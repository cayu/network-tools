#!/usr/bin/perl
# Sergio Cayuqueo <cayu@cayu.com.ar>
# http://cayu.com.ar

open SSH, ("ssh ".$ARGV[0]." -l monitoreo \"sudo /msis/var/opt/MicroStrategy/bin/mstrctl -s IntelligenceServer gs\" | grep state|  sed 's/<[^>]*[>]//g' | sed 's/\\t//g' | sed 's/\\n//g'|");

while ( defined( my $line = <SSH> )  ) {
    chomp($line);
    if ($line eq "running") {
	print "OK - Proceso MicroStrategy corriendo (".$line.")\n";
	exit 0;
    } else {
	print "CRITICAL - Hay un problema con el proceso MicroStrategy (".$line.")\n";
	exit 2;
  }
}
close SSH;
