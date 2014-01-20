#!/bin/bash
WORKDIR=$(pwd)

SCRIPT_NAME=$(basename $0)
USER=$(whoami)
HOST=$(hostname)

# Formatting
T_BOLD=$(tput bold)
T_NORMAL=$(tput sgr0)
T_UNDERSCORE=$(tput smul)
T_GREEN=$(tput setf 2)

if [[ 'vagrant' = "${USER}" ]] || [[ 'vvv' = "${HOST}" ]]; then
	echo "This script must should be run from ${T_UNDERSCORE}outside${T_NORMAL} the vvv host."
	exit 1
fi

# Defaults
UMOUNT=false
CONF="${WORKDIR}/config/mounts.conf"
RELATIVE=true

# Help message
read -d '' HELP << EOH || true
Usage: ${T_BOLD}${0}${T_NORMAL} [-a|--absolute-path] [-u|--umount] [-c <filename>|--config-file=<filename>]

Options:
 -h | -? | --help                    Print this message and exit.
 -a | --absolute-path                Use absolute path for the mount points. If this option is
                                     specified, the script will consider the mount point paths
                                     relative to the ${T_BOLD}current working dir${T_NORMAL}.
 -r | --remount                      Remount.
 -u | --umount                       Umount instead of mount.
 -c ${T_GREEN}<file>${T_NORMAL} | --config-file=${T_GREEN}<file>${T_NORMAL}    Config file location, defaults to ${T_UNDERSCORE}config/mounts.conf${T_NORMAL}
EOH

# Check parameters
while :
do
	case $1 in
		-h | --help | -\?)
			echo -e "${T_BOLD}Mount-bind directories.${T_NORMAL}\n"
			echo -e "${HELP}"
			exit 0
			;;
		-a | --absolute-path)
			RELATIVE=false
			shift
			;;
		-u | --umount)
			UMOUNT=true
			shift
			;;
		-r | --remount)
			$0 "-u" && "$0"
			exit 0
			shift
			;;
		-c | --config-file)
			# You might want to check if you really got CONF
			CONF=$2
			shift 2
			;;
		--config-file=*)
			# Delete everything up till "="
			CONF=${1#*=}
			shift
			;;
		-*)
			echo -e "Unrecognized option.\n"
			echo -e "${HELP}"
			exit 1
			;;
		*)  # no more options. Stop while loop
			break
			;;
	esac
done

# Check config file
if ! [ -f $CONF ]; then
	echo -e "Config file ${T_UNDERSCORE}${CONF}${T_NORMAL} not found, exiting."
	exit 1;
fi

while read LINE; do
	# Skip commented lines
	if [[ "${LINE}" =~ ^#.*$ ]] || [ -z "${LINE}" ]; then
		continue
	fi

	# Replace tabs & spaces with one space
	LINE=$(echo ${LINE} | sed -e 's/[[:space:]]\+/ /g')

	# Must have source and target
	read -a PARTS <<< $LINE;
	[ ${#PARTS[@]} -ne 2 ] && continue;

	SOURCE=${PARTS[0]}
	TARGET=${PARTS[1]}

	if $RELATIVE; then
		TARGET="${WORKDIR}/${TARGET}"
	fi

	# Target cannot be empty
	[ -z "${TARGET}" ] && continue

	if [ -d $SOURCE ]; then
		if $UMOUNT; then
			if [ -d $TARGET ]; then
				echo -e "Unmounting ${T_GREEN}${TARGET}${T_NORMAL}"
				sudo umount $TARGET
			fi
		else
			if [ ! -d $TARGET ]; then
				read -p "${TARGET} doesn't exists, do you want to create it first? [Y/n] " -r < /dev/tty
				if [ -z "${REPLY}" ] || [[ $REPLY =~ ^[Yy]$ ]]; then
					mkdir -p "${TARGET}"
					[ $? -ne '0' ] && continue
				else
					continue
				fi
			fi

			echo -e "Mounting ${T_GREEN}${SOURCE}${T_NORMAL} to ${T_GREEN}${TARGET}${T_NORMAL}"
			sudo mount --bind $SOURCE $TARGET
		fi
	else
		echo -e "${SOURCE} doesn't exist, skipping."
	fi
done < $CONF

exit 0
