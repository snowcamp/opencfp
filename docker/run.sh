#!/bin/bash

set -ex

wait_for_db() {
    while ! mysql -h$DB_PORT_3306_TCP_ADDR -uroot -p$DB_ENV_MYSQL_ROOT_PASSWORD -e "show databases" >/dev/null; do 
	echo "Wait for the db";
	sleep 1
    done
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

update_configuration_files() {
    sed -i "s%host: 127.0.0.1%host: $DB_PORT_3306_TCP_ADDR%" /app/config/production.yml
    sed -i "s%dsn:.*%dsn: mysql:dbname=cfp;host=$DB_PORT_3306_TCP_ADDR%" /app/config/production.yml
    sed -i "s#%datatbase_password%#$DB_ENV_MYSQL_ROOT_PASSWORD#" /app/config/production.yml

    sed -i "s%host: localhost%host: $DB_PORT_3306_TCP_ADDR%" phinx.yml
    sed -i "s%pass: ''%pass: $DB_ENV_MYSQL_ROOT_PASSWORD%" phinx.yml
}

run_migration() {
    cd /app
    vendor/bin/phinx migrate --environment=production
}

wait_for_db
create_db
update_configuration_files
run_migration

exec /usr/local/bin/apache2-foreground
