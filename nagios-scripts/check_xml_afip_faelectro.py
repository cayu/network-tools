#!/usr/bin/python
import errno, sys, urllib2,ssl
from xml.etree.ElementTree import XML

ctx_no_secure = ssl.create_default_context()
ctx_no_secure.set_ciphers('HIGH:!DH:!aNULL')
ctx_no_secure.check_hostname = False
ctx_no_secure.verify_mode = ssl.CERT_NONE

response = urllib2.urlopen('https://serviciosjava.afip.gob.ar/wsmtxca/services/MTXCAService/dummy', context=ctx_no_secure)
xml_afip = XML(response.read())

dummy_afip = {}
contador = 0

for elem in xml_afip:
    dummy_afip[elem.tag]=elem.text
    if elem.text != 'OK':
	    if contador <= 0:
		contador = 1
	    else:
		contador = 1

if contador != 1:
    print "OK - ",dummy_afip,"|rc=0"
    sys.exit(0)
else:
    print "CRITICAL - ",dummy_afip,"|rc=1"
    sys.exit(1)
