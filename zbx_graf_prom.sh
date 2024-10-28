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
# bash <(curl -sL https://raw.githubusercontent.com/andy0mg/b24_ubuntu/refs/heads/main/deploy_full.sh)







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



apt install apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt update
apt -y install docker-ce docker-ce-cli containerd.io docker-compose
git clone https://github.com/zabbix/zabbix-docker.git
cd zabbix-docker/
systemctl start docker
docker compose -f docker-compose_v3_ubuntu_mysql_latest.yaml up -d
