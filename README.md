# network-tools
Mis herramientas para el trabajo de mantenimiento equipos de comunicaciones

## minicom
Ajustes para conectarme via puerto serial a diferentes equipos

## Tips

Siempore que hagas informes, scaneos o lo que fuere. Recordá siempre estos conceptos :

| Subnet Mask | Total IPs  | Usable IPs | CIDR Example | Description                   | First Available IP | Last Available IP |
|-------------|------------|------------|--------------|-------------------------------|---------------------|--------------------|
| /8          | 16,777,216 | 16,777,211 | 10.0.0.0/8   | Very large networks           | 10.0.0.4           | 10.255.255.254    |
| /16         | 65,536     | 65,531     | 10.0.0.0/16  | Large networks                | 10.0.0.4           | 10.0.255.254      |
| /24         | 256        | 251        | 10.0.0.0/24  | Small networks or subnets     | 10.0.0.4           | 10.0.0.254        |
| /25         | 128        | 123        | 10.0.0.0/25  | Smaller subnets               | 10.0.0.4           | 10.0.0.126        |
| /26         | 64         | 59         | 10.0.0.0/26  | Subnets for limited endpoints | 10.0.0.4           | 10.0.0.62         |
| /27         | 32         | 27         | 10.0.0.0/27  | Subnets for fewer endpoints   | 10.0.0.4           | 10.0.0.30         |
| /28         | 16         | 11         | 10.0.0.0/28  | Very small subnets            | 10.0.0.4           | 10.0.0.14         |
| /29         | 8          | 3          | 10.0.0.0/29  | Very small networks           | 10.0.0.4           | 10.0.0.6          |
