Integración de Wazuh con Fortinet

- /var/ossec/etc/decoders/custom_fortigate_decoders.xml
- /var/ossec/etc/rules/custom_fortigate_rules.xml

```bash
# chown root:wazuh /var/ossec/etc/rules/custom_fortigate_rules.xml
# chmod 660 /var/ossec/etc/rules/custom_fortigate_rules.xml
```

/var/ossec/etc/ossec.conf
```
<remote>
<connection>syslog</connection>
<allowed-ips>your-device-ip-1</allowed-ips>
<allowed-ips>your-device-ip-2</allowed-ips>
<allowed-ips>your-device-ip-3</allowed-ips>
</remote>

<ossec_config>
  <remote>
    <connection>syslog</connection>
    <port>514</port>
    <protocol>udp</protocol>
    <allowed-ips>0.0.0.0/0</allowed-ips>
  </remote>
</ossec_config>
```

Fortigate CLI
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

Source :
https://github.com/wazuh/wazuh-kibana-app/issues/1884
