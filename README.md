# Description

# Dependencies
perl, zabbix-agent, zabbix-sender


Installation
============
1. copy domaindiscover.pl to /etc/zabbix/
2. copy zabbix_agentd.d/domain_check.conf to /etc/zabbix/zabbix_agentd.d/
3. copy domain-check.sh to zabbix externalscripts (/usr/lib/zabbix/externalscripts)
4. create /var/cache/zabbix/domain.db on zabbix server.
5. edit the necessary parameters in domain-check.sh script.
6. import "zbx_templates/Template Domain check.xml" into your templates.
7. create host "Domains" (ip 127.0.0.1) and applay "template Domain check" on it.
8. create crontab rule, like:
1 3     * * *   zabbix  /usr/lib/zabbix/externalscripts/domain-check.sh -z 2>&1 > /dev/null



Notes:
==========
Since each registrar provides expiration data in a unique format (if they provide it at all), domain-check is currently only able to
processess expiration information for a subset of the available registrars.

