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
<allowed-ips>192.168.1.0/24</allowed-ips>
</remote>
</ossec_config>
```

Source :
https://github.com/wazuh/wazuh-kibana-app/issues/1884
