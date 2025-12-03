#!/usr/bin/php
<?php
/*
SimpleXMLElement Object
(
    [appserver] => OK
    [authserver] => OK
    [dbserver] => OK
)
*/
$context = stream_context_create(array('ssl'=>array(
    'verify_peer' => false, 
    "verify_peer_name"=>false
    )));

libxml_set_streams_context($context);

$xml_cae_dummy = simplexml_load_file('https://serviciosjava.afip.gob.ar/wsmtxca/services/MTXCAService/dummy');

$appserver_status	= $xml_cae_dummy->appserver;
$authserver_status	= $xml_cae_dummy->authserver;
$dbserver_status	= $xml_cae_dummy->dbserver;

if (($appserver_status == 'OK') && ($authserver_status == 'OK') && ($dbserver_status == 'OK')) {
    print("OK - [appserver] ".$appserver_status." [authserver] ".$authserver_status." [dbserver] ".$dbserver_status."|rc=0\n");
    exit(0);
} else {
    print("CRITICAL - [appserver] ".$appserver_status." [authserver] ".$authserver_status." [dbserver] ".$dbserver_status."|rc=2\n");
    exit(2);
}
?>
