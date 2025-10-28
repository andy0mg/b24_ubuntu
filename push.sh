#!/bin/sh
#
# metadata_begin
# recipe: Bitrix24 GT
# tags: centos7,debian11,debian12
# revision: 6
# description_ru: Рецепт установки Bitrix24
# description_en: Bitrix CMS installing recipe
# metadata_end
#

# use
# bash <(curl -sL https://raw.githubusercontent.com/andy0mg/b24_ubuntu/refs/heads/main/push.sh)

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

if echo $os|grep -E '^Ubuntu' >/dev/null
then
	rediscnf='/etc/redis/redis.conf'
fi

cryptokey=$(echo $RANDOM|md5sum|cut -d' ' -f1)


dplRedis(){
		rediscnf > ${rediscnf}
		echo 'vm.overcommit_memory = 1' >> /etc/sysctl.conf
		sysctl vm.overcommit_memory=1
	  usermod -g www-data redis
    chown redis:redis /etc/redis/ /var/log/redis/
    [[ ! -d /etc/systemd/system/redis.service.d ]] && mkdir /etc/systemd/system/redis.service.d
    echo -e '[Service]\nGroup=www-data\nPIDFile=/run/redis/redis-server.pid' > /etc/systemd/system/redis.service.d/custom.conf
    systemctl daemon-reload
    systemctl stop redis
    systemctl enable --now redis || systemctl enable --now redis-server
    systemctl start redis
}


rediscnf() {
	cat <<-EOF
		pidfile /var/run/redis_6379.pid
		logfile /var/log/redis/redis.log
		dir /var/lib/redis
		bind 127.0.0.1
		protected-mode yes
		port 6379
		tcp-backlog 511
		unixsocketperm 777
		timeout 0
		tcp-keepalive 300
		daemonize yes
		supervised no
		loglevel notice
		databases 16
		save 86400 1
		save 7200 10
		save 3600 10000
		stop-writes-on-bgsave-error no
		rdbcompression yes
		rdbchecksum yes
		dbfilename dump.rdb
		slave-serve-stale-data yes
		slave-read-only yes
		repl-diskless-sync no
		repl-diskless-sync-delay 5
		repl-disable-tcp-nodelay no
		slave-priority 100
		appendonly no
		appendfilename "appendonly.aof"
		appendfsync everysec
		no-appendfsync-on-rewrite no
		auto-aof-rewrite-percentage 100
		auto-aof-rewrite-min-size 64mb
		aof-load-truncated yes
		lua-time-limit 5000
		slowlog-log-slower-than 10000
		slowlog-max-len 128
		latency-monitor-threshold 0
		notify-keyspace-events ""
		hash-max-ziplist-entries 512
		hash-max-ziplist-value 64
		list-max-ziplist-size -2
		list-compress-depth 0
		set-max-intset-entries 512
		zset-max-ziplist-entries 128
		zset-max-ziplist-value 64
		hll-sparse-max-bytes 3000
		activerehashing yes
		client-output-buffer-limit normal 0 0 0
		client-output-buffer-limit slave 256mb 64mb 60
		client-output-buffer-limit pubsub 32mb 8mb 60
		hz 10
		aof-rewrite-incremental-fsync yes
		maxmemory 459mb
		maxmemory-policy allkeys-lru
	EOF
	
		echo unixsocket /var/run/redis/redis.sock


}

dplPush(){
	cd /opt
	#wget -q https://repo.bitrix.info/vm/push-server-0.4.0.tgz
	npm install --production ./push-server-0.4.0.tgz
	rm ./push-server-0.4.0.tgz
	ln -sf /opt/node_modules/push-server/etc/push-server /etc/push-server

	cd /opt/node_modules/push-server
	cp etc/init.d/push-server-multi /usr/local/bin/push-server-multi
	mkdir /etc/sysconfig
	cp etc/sysconfig/push-server-multi  /etc/sysconfig/push-server-multi
	cp etc/push-server/push-server.service  /etc/systemd/system/
	ln -sf /opt/node_modules/push-server /opt/push-server
	useradd -g www-data bitrix

	cat <<EOF >> /etc/sysconfig/push-server-multi
GROUP=www-data
SECURITY_KEY="${cryptokey}"
RUN_DIR=/tmp/push-server
REDIS_SOCK=/var/run/redis/redis.sock
WS_HOST=127.0.0.1
EOF
	/usr/local/bin/push-server-multi configs pub
	/usr/local/bin/push-server-multi configs sub
	echo 'd /tmp/push-server 0770 bitrix www-data -' > /etc/tmpfiles.d/push-server.conf
	systemd-tmpfiles --remove --create
	[[ ! -d /var/log/push-server ]] && mkdir /var/log/push-server
	chown bitrix:www-data /var/log/push-server

	sed -i 's|User=.*|User=bitrix|;s|Group=.*|Group=www-data|;s|ExecStart=.*|ExecStart=/usr/local/bin/push-server-multi systemd_start|;s|ExecStop=.*|ExecStop=/usr/local/bin/push-server-multi stop|' /etc/systemd/system/push-server.service
	systemctl daemon-reload
	systemctl stop push-server
	systemctl --now enable push-server
	systemctl start push-server
}

nfTabl(){
	cat <<EOF > /etc/nftables.conf
#!/usr/sbin/nft -f

flush ruleset

table inet filter {
	chain input {
		type filter hook input priority 0; policy drop;
		iif "lo" accept comment "Accept any localhost traffic"
		ct state invalid drop comment "Drop invalid connections"
		ip protocol icmp limit rate 4/second accept
		ip6 nexthdr ipv6-icmp limit rate 4/second accept
		ct state { established, related } accept comment "Accept traffic originated from us"
		tcp dport 22 accept comment "ssh"
		tcp dport { 8010,8011,8012,8013,8014,8015,9010,9011 } accept comment "push"
	}
	chain forward {
		type filter hook forward priority 0;
	}
	chain output {
		type filter hook output priority 0;
	}
}
EOF
	systemctl restart nftables
	systemctl enable nftables.service
}

if echo $os|grep -Eo 'Ubuntu' >/dev/null
then
	apt update
        timedatectl set-timezone Europe/Moscow
	apt-get install -y software-properties-common apt-transport-https debconf-utils lsb-release wget curl
	type=$(lsb_release -is|tr '[A-Z]' '[a-z]')
	release=$(lsb_release -sc|tr '[A-Z]' '[a-z]')

 
	apt install -y nodejs npm redis \
  nftables net-tools vim
	nfTabl
	dplRedis
	dplPush

 	systemctl restart redis-server push-server
	systemctl enable redis-server push-server
fi

END

bash /root/run.sh
