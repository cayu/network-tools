#!/usr/bin/perl
use Net::SNMP;
$oid = ".1.3.6.1.4.1.2021.8.1.101.1";
 
$snmpv3_username = "consultorsnmp";    # SNMPv3 username
$snmpv3_password = "consultorsnmp123"; # SNMPv3 password
$snmpv3_authprotocol = "md5";          # SNMPv3 hash algorithm (md5 / sha)
$snmpv3_privpassword = "";             # SNMPv3 hash algorithm (md5 / sha)
$snmpv3_privprotocol = "des";          # SNMPv3 encryption protocol (des / aes / aes128)
$version = "3";
$timeout = "2";
$hostname = "127.0.0.1";
# Crear la sesion SNMP
        ($s, $e) = Net::SNMP->session(
                -username       =>  $snmpv3_username,
                -authpassword   =>  $snmpv3_password,
                -authprotocol   =>  $snmpv3_authprotocol,
                -hostname       =>  $hostname,
                -version        =>  $version,
                -timeout        =>  $timeout,
        );
        if ($s){
        } else {
            print "CRITICAL - El agente no responde, SNMP v3 ($e)\n";
            exit(2);
        }
    $s->get_request($oid);
        foreach ($s->var_bind_names()) {
            $oid_consulta   = $s->var_bind_list()->{$_};
        }
$s->close();
print $oid_consulta;
