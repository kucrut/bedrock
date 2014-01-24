#!/bin/bash

pushd $(dirname $0) > /dev/null
BASEDIR=$(dirname $(pwd))
popd > /dev/null

# Info
VERSION='0.1'

# Formatting
T_BOLD=$(tput bold)
T_NORMAL=$(tput sgr0)
T_UNDERSCORE=$(tput smul)
T_GREEN=$(tput setf 2)

# Check .env file
ENV_FILE="${BASEDIR}/.env"
if [ ! -f $ENV_FILE ]; then
	echo "${T_UNDERSCORE}.env${T_NORMAL} file not found. Please create it first by running ${T_GREEN}composer install${T_NORMAL}"
	exit 1
fi
source $ENV_FILE

# Check WordPress config file
WP_CONFIG_FILE="${BASEDIR}/config/application.php"
if [ ! -f $WP_CONFIG_FILE ]; then
	echo "${T_UNDERSCORE}config/application.php${T_NORMAL} file not found, exiting"
	exit 1
fi

# Replace ms-config
sed "s:#MULTISITE_CONFIGS#:define('WP_ALLOW_MULTISITE', true);:" -i $WP_CONFIG_FILE

echo "Please open the following URL in your browser: ${T_GREEN}${WP_SITEURL}/network.php${T_NORMAL}"
echo "Note that you need to select ${T_GREEN}Sub-domains${T_NORMAL}. Sub-directories install is ${T_UNDERSCORE}NOT${T_NORMAL} supported by this stack."
read -p "After clicking the ${T_GREEN}Install${T_NORMAL} button, come back here and press [Enter]... "

read -r -d '' WP_MS_CONFIG << EOC || true < /dev/tty
define('MULTISITE',            true);\\
define('SUBDOMAIN_INSTALL',    true);\\
define('DOMAIN_CURRENT_SITE',  getenv('DOMAIN_CURRENT_SITE') );\\
define('PATH_CURRENT_SITE',    '/');\\
define('SITE_ID_CURRENT_SITE', 1);\\
define('BLOG_ID_CURRENT_SITE', 1);\\
define('ADMIN_COOKIE_PATH',    '/');\\
define('COOKIE_DOMAIN',        '');\\
define('COOKIEPATH',           '');\\
define('SITECOOKIEPATH',       '');
EOC

sed "s:define('WP_ALLOW_MULTISITE', true);:$WP_MS_CONFIG:" -i $WP_CONFIG_FILE

echo "You can now hit the ${T_GREEN}Login${T_NORMAL} link, or go to this URL: ${T_GREEN}${WP_SITEURL}/wp-login.php${T_NORMAL}"
echo -e "${T_GREEN}Enjoy!${T_NORMAL}\n"
