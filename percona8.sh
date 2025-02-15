#!/bin/sh
#

# bash <(curl -sL https://raw.githubusercontent.com/andy0mg/b24_ubuntu/refs/heads/main/percona8.sh)

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
	mycnf='/etc/mysql/conf.d/z9_bitrix.cnf'
fi

mypwd=$(echo $RANDOM|md5sum|head -c 15)
mypwddb=$(echo $RANDOM|md5sum|head -c 15)

mysqlcnf(){
	cat <<-EOF
		[mysqld]
		innodb_buffer_pool_size = 384M
		innodb_buffer_pool_instances = 1
		innodb_flush_log_at_trx_commit = 2
		innodb_flush_method = O_DIRECT
		innodb_strict_mode = OFF
		query_cache_type = 1
		query_cache_size=16M
		query_cache_limit=4M
		key_buffer_size=256M
		join_buffer_size=2M
		sort_buffer_size=4M
		tmp_table_size=128M
		max_heap_table_size=128M
		thread_cache_size = 4
		table_open_cache = 2048
		max_allowed_packet = 128M
		transaction-isolation = READ-COMMITTED
		performance_schema = OFF
		sql_mode = ""
		character-set-server=utf8
		collation-server=utf8_general_ci
		init-connect="SET NAMES utf8"
		explicit_defaults_for_timestamp = 1
	EOF
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
		tcp dport 3306 accept comment "mysql"
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
		apt-get install -y software-properties-common apt-transport-https debconf-utils lsb-release gnupg gnupg2 debian-archive-keyring pwgen make build-essential wget curl
	#type=$(lsb_release -is|tr '[A-Z]' '[a-z]')
	#release=$(lsb_release -sc|tr '[A-Z]' '[a-z]')
	#mkdir -p /etc/apt/keyrings
	#curl -o /etc/apt/keyrings/mariadb-keyring.pgp 'https://mariadb.org/mariadb_release_signing_key.pgp'
	#echo "deb [signed-by=/etc/apt/keyrings/mariadb-keyring.pgp] https://mirror.docker.ru/mariadb/repo/11.4/$type $release main" > /etc/apt/sources.list.d/mariadb.list
	debconf-set-selections <<< "mariadb-server mysql-server/root_password password ${mypwd}"
	debconf-set-selections <<< "mariadb-server mysql-server/root_password_again password ${mypwd}"
	echo -e "[client]\npassword=${mypwd}" > /root/.my.cnf


  wget https://repo.percona.com/apt/percona-release_latest.$(lsb_release -sc)_all.deb;
  dpkg -i percona-release_latest.$(lsb_release -sc)_all.deb; 
  percona-release setup ps80;
	apt update
	apt install -y percona-server-server \
	nftables net-tools vim sysbench perl
  wget https://raw.githubusercontent.com/major/MySQLTuner-perl/master/mysqltuner.pl
	mysql -e "create database bitrix;create user bitrix@'%';grant all on bitrix.* to bitrix@'%';set password for bitrix@'%' = PASSWORD('${mypwddb}')"
	nfTabl
	mysqlcnf > ${mycnf}
	chmod 644 ${mycnf}
	sed -i 's|collation-server=utf8_general_ci|collation-server=utf8mb4_general_ci|' /etc/mysql/conf.d/z9_bitrix.cnf
	chmod 644 ${mycnf}
	systemctl restart mysql
	systemctl enable mysql
fi

END

bash /root/run.sh
