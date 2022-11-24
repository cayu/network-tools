Integración de Wazuh con Fortinet

Hoy en dia esto ya no es necesario : https://github.com/wazuh/wazuh-kibana-app/issues/1884

- /var/ossec/etc/decoders/custom_fortigate_decoders.xml
- /var/ossec/etc/rules/custom_fortigate_rules.xml

```bash
# chown root:wazuh /var/ossec/etc/rules/custom_fortigate_rules.xml
# chmod 660 /var/ossec/etc/rules/custom_fortigate_rules.xml
```


Ya están presentes estas configuraciones en /var/ossec

```
./ruleset/decoders/0100-fortigate_decoders.xml
./ruleset/decoders/0101-fortiddos_decoders.xml
./ruleset/decoders/0102-fortimail_decoders.xml
./ruleset/decoders/0103-fortiauth_decoders.xml
./ruleset/rules/0390-fortiddos_rules.xml
./ruleset/rules/0391-fortigate_rules.xml
./ruleset/rules/0392-fortimail_rules.xml
./ruleset/rules/0393-fortiauth_rules.xml
```

Si hay que habilitar el servicio de Syslog en Wazuh

/var/ossec/etc/ossec.conf
```
<ossec_config>
  <remote>
    <connection>syslog</connection>
    <port>514</port>
    <protocol>udp</protocol>
    <allowed-ips>0.0.0.0/0</allowed-ips>
  </remote>
</ossec_config>
```
Y en el FortiGate desde la CLI debemos aplicar una configuración similar a esta :
```
# config global
# config log syslogd setting
    set status enable
    set server "192.168.3.2"
    set mode udp
    set port 514
    set facility local7
    set source-ip '192.168.2.1'
    set format default
    set priority default
    set max-log-rate 0
    set interface-select-method auto
end
``
