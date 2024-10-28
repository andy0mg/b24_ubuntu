#!/bin/sh
#
# metadata_begin
# recipe: zabbix_docker
# tags: 
# revision: 6
# description_ru: Рецепт установки zabbix docker

# metadata_end
#

# use
# bash <(curl -sL https://raw.githubusercontent.com/andy0mg/b24_ubuntu/refs/heads/main/zbx_graf_prom.sh)

cat > /root/run.sh <<\END

set -x
LOG_PIPE=/tmp/log.pipe
mkfifo ${LOG_PIPE}
LOG_FILE=/root/recipe.log
touch ${LOG_FILE}
chmod 600 ${LOG_FILE}
tee < ${LOG_PIPE} ${LOG_FILE} &
exec > ${LOG_PIPE}
exec 2> ${LOG_PIPE}

os=`set -o pipefail && { cat /etc/centos-release || { source /etc/os-release && echo $PRETTY_NAME; } ;}`

prom_graf() {
	cat <<-EOF
version: '3.9'
services:

  prometheus:
    image: prom/prometheus:latest
    volumes:
      - ./prometheus:/etc/prometheus/
    container_name: prometheus
    hostname: prometheus
    command:
      - --config.file=/etc/prometheus/prometheus.yml
    ports:
      - 9090:9090
    restart: unless-stopped
    environment:
      TZ: "Europe/Moscow"
    networks:
      - default

  node-exporter:
    image: prom/node-exporter
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    container_name: exporter
    hostname: exporter
    command:
      - --path.procfs=/host/proc
      - --path.sysfs=/host/sys
      - --collector.filesystem.ignored-mount-points
      - ^/(sys|proc|dev|host|etc|rootfs/var/lib/docker/containers|rootfs/var/lib/docker/overlay2|rootfs/run/docker/netns|rootfs/var/lib/docker/aufs)($$|/)
    ports:
      - 9100:9100
    restart: unless-stopped
    environment:
      TZ: "Europe/Moscow"
    networks:
      - default

  grafana:
    image: grafana/grafana
    user: root
    depends_on:
      - prometheus
    ports:
      - 3000:3000
    volumes:
      - ./grafana:/var/lib/grafana
      - ./grafana/provisioning/:/etc/grafana/provisioning/
    container_name: grafana
    hostname: grafana
    restart: unless-stopped
    environment:
      GF_INSTALL_PLUGINS: "grafana-clock-panel,grafana-simple-json-datasource,grafana-worldmap-panel,grafana-piechart-panel,alexanderzobnin-zabbix-app"
      TZ: "Europe/Moscow"
    networks:
      - default

networks:
  default:
    ipam:
      driver: default
      config:
        - subnet: 172.28.0.0/16
		EOF
}

prom_conf() {
	cat <<-EOF
		# my global config
		global:
		  scrape_interval: 15s # Set the scrape interval to every 15 seconds. Default is every 1 minute.
		  evaluation_interval: 15s # Evaluate rules every 15 seconds. The default is every 1 minute.
		  # scrape_timeout is set to the global default (10s).

		# Alertmanager configuration
		alerting:
		  alertmanagers:
  		  - static_configs:
    		    - targets:
      		    # - alertmanager:9093

		# Load rules once and periodically evaluate them according to the global 'evaluation_interval'.
		rule_files:
		  # - "first_rules.yml"
		  # - "second_rules.yml"

		# A scrape configuration containing exactly one endpoint to scrape:
		# Here it's Prometheus itself.
		scrape_configs:
 		 # The job name is added as a label `job=<job_name>` to any timeseries scraped from this config.
  		- job_name: "prometheus"

    		# metrics_path defaults to '/metrics'
   		 # scheme defaults to 'http'.

   		 static_configs:
    		  - targets: ["localhost:9090"]


  		- job_name: 'jmeter'
   		 scrape_interval: 5s
   		 static_configs:
    		- targets: ['192.168.1.1:9270', '192.168.1.2:9270']
    
			EOF
		}

if echo $os|grep -Eo 'Ubuntu' >/dev/null
then
apt install apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt update
apt -y install docker-ce docker-ce-cli containerd.io docker-compose
git clone https://github.com/zabbix/zabbix-docker.git
cd zabbix-docker/
git checkout 6.4
prom_graf > docker-compose_v3_prom_graf.yml
mkdir prometheus
prom_conf > ./prometheus/prometheus.yml
systemctl start docker
docker compose -f docker-compose_v3_ubuntu_mysql_latest.yaml up -d
docker compose -f docker-compose_v3_prom_graf.yml up -d
fi
ip=$(wget -qO- "https://ipinfo.io/ip")

	END

bash /root/run.sh
