#!/bin/bash

pushd $(dirname $0) > /dev/null
BASEDIR=$(dirname $(pwd))
popd > /dev/null

VERSION='0.1'
SCRIPT_NAME=$(basename $0)
USER=$(whoami)
HOST=$(hostname)

if [[ 'vagrant' != "${USER}" ]] || [[ 'vvv' != "${HOST}" ]]; then
	echo "${SCRIPT_NAME} must be run by the vvv user inside vagrant host."
	exit 1
fi

# Formatting
T_BOLD=$(tput bold)
T_NORMAL=$(tput sgr0)
T_UNDERSCORE=$(tput smul)

# Defaults
REINIT=false

# Help Message
read -d '' HELP << EOH || true
${T_BOLD}USAGE:${T_NORMAL} ${SCRIPT_NAME} [-r] [-h|-?|--help]

${T_BOLD}OPTIONS:${T_NORMAL}
  -h, -?, --help
      Print this message and exit.

  -r, --reinit
      Reinitialize site. This will (re)create the ${T_UNDERSCORE}vvv-hosts${T_NORMAL} and ${T_UNDERSCORE}vvv-nginx.conf${T_NORMAL}
      files inside the ${T_UNDERSCORE}config/${T_NORMAL} directory.
EOH

while :
do
	case $1 in
		-h | --help | -\?)
			echo "${HELP}"
			exit 0
			;;
		-r | --reinit)
			REINIT=true
			shift
			;;
		-V | --version)
			echo -e "${SCRIPT_NAME} version ${VERSION}"
			echo -e "Copyleft ${T_BOLD}Dzikri Aziz${T_NORMAL} <kucrut@kucrut.org>"
			exit 0
			;;
		-*)
			echo -e "Unrecognized option '${1}'\n"
			echo -e "${HELP}"
			exit 1
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
DONE_MESSAGE="\n${T_BOLD}${SITENAME}${T_NORMAL} is ready!\n"

echo -e "\n## Provisioning ${T_BOLD}${SITENAME}${T_NORMAL} ##\n"

# Get domain names
if [ -z "${DOMAIN_NAMES}" ]; then
	DOMAIN_NAMES=$SITENAME
fi

# Create database, if we don't already have one
echo " * Creating database ${T_BOLD}${DB_NAME}${T_NORMAL}";
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

if ! $REINIT; then
	echo -e ${DONE_MESSAGE}
	exit 0;
fi

# Reinit
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
	echo -e "\n*** Add the following lines to your ${T_BOLD}HOST SYSTEM's${T_NORMAL} ${T_UNDERSCORE}/etc/hosts${T_NORMAL} file ***\n"
	echo -e "### ${BORDER} ###"
	echo -e $ADD_TO_HOST | sed '/^$/d'
	echo -e "### ${BORDER} ###\n"
fi

# Finally, restart nginx
sudo service nginx restart

echo -e ${DONE_MESSAGE}
exit 0;
