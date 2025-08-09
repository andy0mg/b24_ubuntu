#!/bin/sh
#

# bash <(curl -sL https://raw.githubusercontent.com/andy0mg/b24_ubuntu/refs/heads/main/percona84.sh)

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
		[client]
port = 3306
socket = /run/mysqld/mysqld.sock
default-character-set = utf8mb4

[mysqld]
port = 3306
bind-address = 0.0.0.0
#mysqlx_bind_address = 127.0.0.1
datadir = /var/lib/mysql
socket = /run/mysqld/mysqld.sock
pid-file = /run/mysqld/mysqld.pid
skip-name-resolve
sql_mode = ""

# Logging configuration.
log-error = /var/log/mysql/mysql.log

# Disable binlog to save disk space
#disable-log-bin


# Disabling symbolic-links is recommended to prevent assorted security risks

# User is ignored when systemd is used (fedora >= 15).
user = mysql

# http://dev.mysql.com/doc/refman/5.5/en/performance-schema.html
performance_schema = ON

# Memory settings.
key_buffer_size = 8M
max_allowed_packet = 256M
table_open_cache = 4096
sort_buffer_size = 14M
join_buffer_size = 14M
read_buffer_size = 16M
read_rnd_buffer_size = 16M
myisam_sort_buffer_size = 1M
thread_cache_size = 32
max_connections = 50
tmp_table_size = 256M
max_heap_table_size = 256M
group_concat_max_len = 1024

# Other settings.
lower_case_table_names = 0
transaction_isolation = READ-COMMITTED
log_timestamps = SYSTEM
event_scheduler = OFF
low_priority_updates

# collations
character_set_server = utf8mb4
collation_server = utf8mb4_general_ci
init_connect = 'SET NAMES utf8mb4 COLLATE utf8mb4_general_ci'

# thread handling

# InnoDB settings.
innodb_dedicated_server = ON
#innodb_buffer_pool_size = 3072M
#innodb_redo_log_capacity = 768M
#innodb_buffer_pool_instances = 3
innodb_file_per_table = 1

innodb_log_buffer_size = 64M
innodb_flush_log_at_trx_commit = 2
innodb_flush_method = O_DIRECT
innodb_lock_wait_timeout = 50
innodb_strict_mode = OFF

# Disable Percona Telemetry
percona_telemetry_disable = 1

[mysqldump]
quick
quote-names
max_allowed_packet = 256M

[mysqld_safe]
pid-file = /run/mysqld/mysqld.pid
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
  percona-release enable-only ps-84-lts release
  percona-release enable pt release
  apt install -y percona-server-server percona-toolkit  sysbench
	apt update
	apt install -y nftables net-tools vim perl
  wget https://raw.githubusercontent.com/major/MySQLTuner-perl/master/mysqltuner.pl
	mysql -e "create database bitrix;create user bitrix@'%' IDENTIFIED BY '${mypwddb}';grant all on bitrix.* to bitrix@'%';"
	nfTabl
	mysqlcnf > ${mycnf}
	chmod 644 ${mycnf}
	sed -i 's|collation-server=utf8_general_ci|collation-server=utf8mb4_general_ci|' /etc/mysql/conf.d/z9_bitrix.cnf
 	#mysql -e "CREATE FUNCTION fnv1a_64 RETURNS INTEGER SONAME 'libfnv1a_udf.so'"
    #    mysql -e "CREATE FUNCTION fnv_64 RETURNS INTEGER SONAME 'libfnv_udf.so'"
    #    mysql -e "CREATE FUNCTION murmur_hash RETURNS INTEGER SONAME 'libmurmur_udf.so'"

	chmod 644 ${mycnf}
	systemctl restart mysql
	systemctl enable mysql
fi

END

bash /root/run.sh
