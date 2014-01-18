#!/bin/bash

pushd $(dirname $0) > /dev/null
BASEDIR=$(dirname $(pwd))
popd > /dev/null

SCRIPT_NAME=$(basename $0)
USER=$(whoami)
HOST=$(hostname)

if [[ 'vagrant' != "${USER}" ]] || [[ 'vvv' != "${HOST}" ]]; then
	echo "${SCRIPT_NAME} must be run by the vvv user inside vagrant host."
	exit 1
fi

T_BOLD=$(tput bold)
T_NORMAL=$(tput sgr0)
T_UNDERSCORE=$(tput smul)

while :
do
	case $1 in
		-h | --help | -\?)
cat << HELP

Usage: ${SCRIPT_NAME} [-r]

Options:
 -h or --help      Print this message and exit.
 -r or --reinit    Reinitialize site. This will (re)create the ${T_UNDERSCORE}vvv-hosts${T_NORMAL} and
                   ${T_UNDERSCORE}vvv-nginx.conf${T_NORMAL} files inside the ${T_UNDERSCORE}config/${T_NORMAL} directory.

HELP
			exit 0      # This is not an error, User asked help. Don't do "exit 1"
			;;
		#-f | --file)
		#	# You might want to check if you really got FILE
		#	file=$2
		#	shift 2
		#	;;
		#--file=*)
		#	# Delete everything up till "="
		#	file=${1#*=}
		#	shift
		#	;;
		-*)
			shift
			;;
		*)  # no more options. Stop while loop
			break
			;;
	esac
done

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
echo " * Creating database '${DB_NAME}'";
SQL="CREATE DATABASE IF NOT EXISTS ${DB_NAME} DEFAULT CHARACTER SET 'utf8' COLLATE 'utf8_unicode_ci';"
SQL="${SQL} GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO ${DB_USER}@${DB_HOST} IDENTIFIED BY '${DB_PASSWORD}';"
mysql -u root --password=root -e "${SQL}"

# Create log files
echo -e " * Creating log files:"
for FILENAME in access error php; do
	FILEPATH="/var/log/nginx/${SITENAME}_${FILENAME}.log"
	echo -e "   * ${FILEPATH}"
	sudo touch ${FILEPATH}
done

# Copy our base nginx file
if ! [ -f /etc/nginx/nginx-wp-owndir.conf ]; then
	echo -e "Copying base Nginx config file\n";
	sudo cp "${BASEDIR}/config/nginx-wp-owndir.conf" /etc/nginx/nginx-wp-owndir.conf
fi

# Create nginx config file
echo " * Creating nginx config file"
NGINX_CONF="${BASEDIR}/config/vvv-nginx.conf"
cat > $NGINX_CONF <<EOF
server {
	listen        80;
	listen        443 ssl;
	server_name   ${DOMAIN_NAMES};

	root          ${BASEDIR}/root;
	access_log    /var/log/nginx/${SITENAME}_access.log;
	error_log     /var/log/nginx/${SITENAME}_error.log;
	fastcgi_param PHP_VALUE "error_log=/var/log/nginx/${SITENAME}_php.log";

	include /etc/nginx/nginx-wp-owndir.conf;
}
EOF

# Create hosts file
VVV_HOSTS_FILE="${BASEDIR}/config/vvv-hosts"
echo " * Creating vvv hosts file"
for DOMAIN_NAME in $DOMAIN_NAMES; do
	if [[ "#" != ${DOMAIN_NAME:0:1} ]] && [[ "*" != ${DOMAIN_NAME:0:1} ]]; then
		HOST_NAMES="$HOST_NAMES$DOMAIN_NAME\n"
	fi
done
echo -e $HOST_NAMES > $VVV_HOSTS_FILE

# Manual invocation
if [ -n "$1" ] && [[ "-r" = "$1" ]]; then
	DIR_NAME=$(basename $BASEDIR)
	echo -e "\nThe script was manually invoked. It will try to replace the existing nginx config for this site, but no promises :P";

	NGINX_CONFIG_DIR="/etc/nginx/custom-sites"
	OLD_CONFIGS=$(find $NGINX_CONFIG_DIR -name "*${DIR_NAME}*")
	if [ -n "$OLD_CONFIGS" ]; then
		echo " * Old Nginx config found and moved to /tmp:"
		for FILE_NAME in $OLD_CONFIGS; do
			echo "   * /tmp/$(basename ${FILE_NAME})"
		done
		sudo mv $OLD_CONFIGS /tmp
	fi

	NEW_CONFIG="${NGINX_CONFIG_DIR}/${DIR_NAME}.conf"
	sudo cp $NGINX_CONF $NEW_CONFIG
	echo " * New Nginx config added: ${NEW_CONFIG}"

	echo " * Checking host names:"
	VVV_IP=$(ip addr list eth1 |grep "inet " |cut -d' ' -f6|cut -d/ -f1)
	BORDER_LENGTH=0
	while IFS='' read -r DOMAIN_NAME && [ -n "$DOMAIN_NAME" ]; do
		if [[ "#" != ${DOMAIN_NAME:0:1} ]] && [[ "*" != ${DOMAIN_NAME:0:1} ]]; then
			echo "   * ${DOMAIN_NAME}"

			NEW_ADD_TO_HOST="${VVV_IP} ${DOMAIN_NAME} # vvv-auto"
			LENGTH=${#NEW_ADD_TO_HOST}
			[ $LENGTH -gt $BORDER_LENGTH ] && BORDER_LENGTH=$LENGTH
			ADD_TO_HOST="${ADD_TO_HOST}${NEW_ADD_TO_HOST}\n"

			if ! $(grep -q "^127.0.0.1 ${DOMAIN_NAME}" /etc/hosts); then
				NEW_HOSTS="${NEW_HOSTS}127.0.0.1 ${DOMAIN_NAME} # vvv-auto\n"
			fi
		fi
	done < $VVV_HOSTS_FILE

	if [ -n "${NEW_HOSTS}" ]; then
		echo -e $NEW_HOSTS | sudo tee -a /etc/hosts > /dev/null
	fi

	if [ -n "${ADD_TO_HOST}" ]; then
		BORDER_CHAR="="
		BORDER_LENGTH=$((${BORDER_LENGTH} - 8))
		BORDER=$(printf "%${BORDER_LENGTH}s" | sed "s/ /${BORDER_CHAR}/g" )
		echo -e "\n*** Add the following lines to your HOST SYSTEM's /etc/hosts file ***\n"
		echo -e "### ${BORDER} ###"
		echo -e $ADD_TO_HOST | sed '/^$/d'
		echo -e "### ${BORDER} ###\n"
	fi

	# Finally, restart nginx
	sudo service nginx restart
fi

echo -e "\n${SITENAME} is ready!\n"
