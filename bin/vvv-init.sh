#!/bin/bash

pushd $(dirname $0) > /dev/null
BASEDIR=$(dirname $(pwd))
popd > /dev/null

ENV_FILE="${BASEDIR}/.env"
if ! [ -f $ENV_FILE ]; then
	echo -e ".env file not found in ${BASEDIR}, exiting.\n"
	exit 1
fi

source $ENV_FILE

# Get sitename
SITENAME=$(echo $WP_HOME | sed 's/^http\(\|s\):\/\///g')

echo -e "\n## Provisioning ${SITENAME} ##"

# Get domain names
if [ -z "${DOMAIN_NAMES}" ]; then
	DOMAIN_NAMES=$SITENAME
fi

# Create database, if we don't already have one
echo "* Creating database '${DB_NAME}'";
SQL="CREATE DATABASE IF NOT EXISTS ${DB_NAME} DEFAULT CHARACTER SET 'utf8' COLLATE 'utf8_unicode_ci';"
SQL="${SQL} GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO ${DB_USER}@${DB_HOST} IDENTIFIED BY '${DB_PASSWORD}';"
mysql -u root --password=root -e "${SQL}"

# Create log files
echo -e "* Creating log files:"
for FILENAME in access error php; do
	FILEPATH="/var/log/nginx/${SITENAME}_${FILENAME}.log"
	echo -e "  * ${FILEPATH}"
	sudo touch ${FILEPATH}
done

# Copy our base nginx file
if ! [ -f /etc/nginx/nginx-wp-owndir.conf ]; then
	echo -e "Copying base Nginx config file\n";
	sudo cp "${BASEDIR}/config/nginx-wp-owndir.conf" /etc/nginx/nginx-wp-owndir.conf
fi

# Create nginx config file
echo "* Creating nginx config file"

cat > "${BASEDIR}/config/vvv-nginx.conf" <<EOF
server {
	listen        80;
	listen        443 ssl;
	server_name   ${DOMAIN_NAMES};

	root          ${BASEDIR}/root;
	access_log    /var/log/nginx/${SITENAME}_access.log;
	error_log     /var/log/nginx/${SITENAME}_error.log;
	fastcgi_param PHP_VALUE "error_log=/var/log/nginx/${SITENAME}_php.log";

	include /etc/nginx/nginx-wp-owndir.conf
}
EOF

# Create hosts file
echo "* Creating vvv hosts file"
echo $DOMAIN_NAMES | sed -e 's/\s\+/\n/g' > "${BASEDIR}/config/vvv-hosts"

echo -e "## ${SITENAME} is ready!##\n"
