#!/bin/sh
#

# bash <(curl -sL https://raw.githubusercontent.com/andy0mg/b24_ubuntu/refs/heads/main/zabbix_agent.sh)

cat > /root/run.sh <<\END

set -x
wget https://repo.zabbix.com/zabbix/6.4/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest+ubuntu24.04_all.deb
dpkg -i zabbix-release_latest+ubuntu24.04_all.deb
apt update
apt install -y zabbix-agent
sed -i 's/Hostname=Zabbix server/#Hostname=Zabbix server/g' /etc/zabbix/zabbix_agentd.conf
sed -i 's/# HostnameItem=system.hostname/HostnameItem=system.hostname/g' /etc/zabbix/zabbix_agentd.conf
sed -i 's/Server=127.0.0.1/Server=10.120.5.234/g' /etc/zabbix/zabbix_agentd.conf
sed -i 's/ServerActive=127.0.0.1/ServerActive=10.120.5.234/g' /etc/zabbix/zabbix_agentd.conf
systemctl restart zabbix-agent
systemctl enable zabbix-agent

END

bash /root/run.sh
