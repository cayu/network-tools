Integración de Wazuh con Fortinet

- /var/ossec/etc/decoders/custom_fortigate_decoders.xml
- /var/ossec/etc/rules/custom_fortigate_rules.xml

```bash
# chown root:wazuh /var/ossec/etc/rules/custom_fortigate_rules.xml
# chmod 660 /var/ossec/etc/rules/custom_fortigate_rules.xml
```

Source :
https://github.com/wazuh/wazuh-kibana-app/issues/1884
