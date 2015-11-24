#!/bin/bash

set -ex

error() {
    echo "*** ERROR $@" >2
    exit 1
}

check_env() {
    if [ -z "$DB_PORT_3306_TCP_ADDR" ]; then
	error "No db connexion, did you forget --link ?"
    fi
    if [ -z "$MANDRILL_USERNAME" ]; then
	error "No MANDRILL_USERNAME variable"
    fi
    if [ -z "$MANDRILL_PASSWORD" ]; then
	error "No MANDRILL_PASSWORD variable"
    fi
}

wait_for_db() {
    while ! mysql -h$DB_PORT_3306_TCP_ADDR -uroot -p$DB_ENV_MYSQL_ROOT_PASSWORD -e "show databases" >/dev/null; do 
	echo "Wait for the db";
	sleep 1
    done
    sleep 5
}

db_exists() {
    db=$(mysql -h$DB_PORT_3306_TCP_ADDR -uroot -p$DB_ENV_MYSQL_ROOT_PASSWORD -e "show databases like 'cfp'")
    if [ -z "$db" ]; then
	false
    else
	true
    fi
}

create_db() {
    if ! db_exists; then
	mysql -h$DB_PORT_3306_TCP_ADDR -uroot -p$DB_ENV_MYSQL_ROOT_PASSWORD -e "create database cfp"
    fi
}

setup_environment() {
   cp docker/$CFP_ENV.dist.yml /app/config/$CFP_ENV.yml
   sed -i "s/%CFP_ENV%/$CFP_ENV/" /etc/apache2/sites-enabled/opencfp.conf
   sed -i "s/%CFP_ENV%/$CFP_ENV/" /app/phinx.yml
}

update_configuration_files() {
    sed -i \
	-e "s%host: 127.0.0.1%host: $DB_PORT_3306_TCP_ADDR%" \
	-e "s%dsn:.*%dsn: mysql:dbname=cfp;host=$DB_PORT_3306_TCP_ADDR%" \
	-e "s#%datatbase_password%#$DB_ENV_MYSQL_ROOT_PASSWORD#" \
	-e "s#%mail_username%#$MANDRILL_USERNAME#" \
	-e "s#%mail_password%#$MANDRILL_PASSWORD#" \
	/app/config/$CFP_ENV.yml

    sed -i "s%host: localhost%host: $DB_PORT_3306_TCP_ADDR%" phinx.yml
    sed -i "s%pass: ''%pass: $DB_ENV_MYSQL_ROOT_PASSWORD%" phinx.yml
}

run_migration() {
    cd /app
    vendor/bin/phinx migrate --environment=$CFP_ENV
}

link_data_dir() {
    if [ ! -f /data/uploads/dummyphoto.jpg ]; then
	install -d -m 0750 -o www-data -g www-data /data/uploads
	cp /app/web/uploads/dummyphoto.jpg /data/uploads
    fi
    chmod 0755 /data
    chown -R www-data.www-data /data/uploads
    rm -rf /app/web/uploads
    ln -s /data/uploads /app/web/uploads
}

check_env
wait_for_db
create_db
setup_environment
update_configuration_files
run_migration
link_data_dir

touch /var/log/php_errors.log
chown www-data:www-data /var/log/php_errors.log

exec /usr/local/bin/apache2-foreground
