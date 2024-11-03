

apt update && apt upgrade
apt install -y default-jdk wget
wget https://dlcdn.apache.org//jmeter/binaries/apache-jmeter-5.6.3.zip
unzip apache-jmeter-5.*.zip
mv apache-jmeter-5.6.3 jmeter
mv jmeter /opt
echo 'export PATH="$PATH:/opt/jmeter/bin"' >> ~/.bashrc
source ~/.bashrc
sed -i 's/HEAP:="-Xms1g -Xmx1g/HEAP:="-Xms16g -Xmx24g/g' /opt/jmeter/bin/jmeter
sed -i 's/#server.rmi.ssl.disable=false/server.rmi.ssl.disable=true/g' /opt/jmeter/bin/jmeter.properties
tee /etc/sysctl.d/99-jmeter.conf <<EOF
net.ipv4.tcp_tw_reuse = 1
net.core.somaxconn = 60000
net.core.netdev_max_backlog = 7000
net.ipv4.tcp_max_syn_backlog = 7000
net.ipv4.ip_local_port_range = 2000 65000
EOF

sysctl -p /etc/sysctl.d/99-jmeter.conf

