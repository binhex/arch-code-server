#!/bin/bash

# exit script if return code != 0
set -e

# app name from buildx arg, used in healthcheck to identify app and monitor correct process
APPNAME="${1}"
shift

# release tag name from buildx arg, stripped of build ver using string manipulation
RELEASETAG="${1}"
shift

# target arch from buildx arg
TARGETARCH="${1}"
shift

if [[ -z "${APPNAME}" ]]; then
	echo "[warn] App name from build arg is empty, exiting script..."
	exit 1
fi

if [[ -z "${RELEASETAG}" ]]; then
	echo "[warn] Release tag name from build arg is empty, exiting script..."
	exit 1
fi

if [[ -z "${TARGETARCH}" ]]; then
	echo "[warn] Target architecture name from build arg is empty, exiting script..."
	exit 1
fi

# write APPNAME and RELEASETAG to file to record the app name and release tag used to build the image
echo -e "export APPNAME=${APPNAME}\nexport IMAGE_RELEASE_TAG=${RELEASETAG}\n" >> '/etc/image-build-info'

# ensure we have the latest builds scripts
refresh.sh

# pacman packages
####

# define pacman packages
pacman_packages="git python python-pip openssl-1.1 rsync"

# install compiled packages using pacman
if [[ -n "${pacman_packages}" ]]; then
	# arm64 currently targetting aor not archive, so we need to update the system first
	if [[ "${TARGETARCH}" == "arm64" ]]; then
		pacman -Syu --noconfirm
	fi
	pacman -S --needed ${pacman_packages} --noconfirm
fi

# aur packages
####

# define aur packages
aur_packages="code-server"

# call aur install script (arch user repo)
aur.sh --aur-package "${aur_packages}"

# custom
####

# replace nasty web icon with ms version
cp -f '/home/nobody/icons/favicon'* '/usr/lib/code-server/src/browser/media/'
cp -f '/usr/lib/code-server/src/browser/media/favicon.svg' '/usr/lib/code-server/src/browser/media/favicon-dark-support.svg'

# env vars
####

cat <<'EOF' > /tmp/envvars_heredoc

export PASSWORD=$(echo "${PASSWORD}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
if [[ ! -z "${PASSWORD}" ]]; then
	if [[ "${PASSWORD}" == "code-server" ]]; then
		echo "[warn] PASSWORD defined as '${PASSWORD}' is weak, please consider using a stronger password" | ts '%Y-%m-%d %H:%M:%.S'
	else
		echo "[info] PASSWORD defined as '${PASSWORD}'" | ts '%Y-%m-%d %H:%M:%.S'
	fi
else
	WEBUI_PASS_file="/config/code-server/security/webui"
	if [ ! -f "${WEBUI_PASS_file}" ]; then
		# generate random password for web ui using SHA to hash the date,
		# run through base64, and then output the top 16 characters to a file.
		mkdir -p "/config/code-server/security" ; chown -R nobody:users "/config/code-server"
		date +%s | sha256sum | base64 | head -c 16 > "${WEBUI_PASS_file}"
	fi
	echo "[warn] PASSWORD not defined (via -e PASSWORD), using randomised password (password stored in '${WEBUI_PASS_file}')" | ts '%Y-%m-%d %H:%M:%.S'
	export PASSWORD="$(cat ${WEBUI_PASS_file})"
fi

export CERT_PATH=$(echo "${CERT_PATH}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
if [[ ! -z "${CERT_PATH}" ]]; then
	echo "[info] CERT_PATH defined as '${CERT_PATH}'" | ts '%Y-%m-%d %H:%M:%.S'
else
	echo "[info] CERT_PATH not defined,(via -e CERT_PATH)" | ts '%Y-%m-%d %H:%M:%.S'
	export CERT_PATH=""
fi

export CERT_KEY_PATH=$(echo "${CERT_KEY_PATH}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
if [[ ! -z "${CERT_KEY_PATH}" ]]; then
	echo "[info] CERT_KEY_PATH defined as '${CERT_KEY_PATH}'" | ts '%Y-%m-%d %H:%M:%.S'
else
	echo "[info] CERT_KEY_PATH not defined,(via -e CERT_KEY_PATH)" | ts '%Y-%m-%d %H:%M:%.S'
	export CERT_KEY_PATH=""
fi

export SELF_SIGNED_CERT=$(echo "${SELF_SIGNED_CERT}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
if [[ ! -z "${SELF_SIGNED_CERT}" ]]; then
	echo "[info] SELF_SIGNED_CERT defined as '${SELF_SIGNED_CERT}'" | ts '%Y-%m-%d %H:%M:%.S'
else
	echo "[info] SELF_SIGNED_CERT not defined,(via -e SELF_SIGNED_CERT), defaulting to 'no'" | ts '%Y-%m-%d %H:%M:%.S'
	export SELF_SIGNED_CERT="no"
fi

export BIND_CLOUD_NAME=$(echo "${BIND_CLOUD_NAME}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
if [[ ! -z "${BIND_CLOUD_NAME}" ]]; then
	echo "[info] BIND_CLOUD_NAME defined as '${BIND_CLOUD_NAME}'" | ts '%Y-%m-%d %H:%M:%.S'
else
	echo "[info] BIND_CLOUD_NAME not defined,(via -e BIND_CLOUD_NAME)" | ts '%Y-%m-%d %H:%M:%.S'
	export BIND_CLOUD_NAME=""
fi

export ENABLE_STARTUP_SCRIPTS=$(echo "${ENABLE_STARTUP_SCRIPTS}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
if [[ ! -z "${ENABLE_STARTUP_SCRIPTS}" ]]; then
	echo "[info] ENABLE_STARTUP_SCRIPTS defined as '${ENABLE_STARTUP_SCRIPTS}'" | ts '%Y-%m-%d %H:%M:%.S'
else
	echo "[info] ENABLE_STARTUP_SCRIPTS not defined,(via -e ENABLE_STARTUP_SCRIPTS), defaulting to 'no'" | ts '%Y-%m-%d %H:%M:%.S'
	export ENABLE_STARTUP_SCRIPTS="no"
fi

EOF

# replace env vars placeholder string with contents of file (here doc)
sed -i '/# ENVVARS_PLACEHOLDER/{
    s/# ENVVARS_PLACEHOLDER//g
    r /tmp/envvars_heredoc
}' /usr/bin/init.sh
rm /tmp/envvars_heredoc

cat <<'EOF' > /tmp/config_heredoc

if [[ "${ENABLE_STARTUP_SCRIPTS}" == "yes" ]]; then

	# define path to scripts
	base_path="/config/code-server"
	user_script_path="${base_path}/scripts"

	mkdir -p "${user_script_path}"

	# copy example startup script
	# note slence stdout/stderr and ensure exit code 0 due to src file may not exist (symlink)
	if [[ ! -f "${user_script_path}/example-startup-script.sh" ]]; then
		cp "/home/nobody/example-startup-script.sh" "${user_script_path}/example-startup-script.sh" 2> /dev/null || true
	fi

	# find any scripts located in "${user_script_path}"
	user_scripts=$(find "${user_script_path}" -maxdepth 1 -name '*sh' 2> '/dev/null' | xargs)

	# loop over scripts, make executable and source
	for i in ${user_scripts}; do
		chmod +x "${i}"
		echo "[info] Executing user script '${i}' in the background" | ts '%Y-%m-%d %H:%M:%.S'
		source "${i}" &
	done

	# change ownership as we are running as root
	chown -R nobody:users "${base_path}"

fi

# call symlink function from utils.sh
symlink --src-path '/config/home' --dst-path '/home/nobody' --link-type 'softlink'
EOF

# replace config placeholder string with contents of file (here doc)
sed -i '/# CONFIG_PLACEHOLDER/{
    s/# CONFIG_PLACEHOLDER//g
    r /tmp/config_heredoc
}' /usr/bin/init.sh
rm /tmp/config_heredoc

# container perms
####

# create path to store temporary files
mkdir -p '/usr/lib/code'

# define comma separated list of paths
install_paths="/home/nobody,/usr/lib/code,/usr/lib/code-server"

# split comma separated string into list for install paths
IFS=',' read -ra install_paths_list <<< "${install_paths}"

# process install paths in the list
for i in "${install_paths_list[@]}"; do

	# confirm path(s) exist, if not then exit
	if [[ ! -d "${i}" ]]; then
		echo "[crit] Path '${i}' does not exist, exiting build process..." ; exit 1
	fi

done

# convert comma separated string of install paths to space separated, required for chmod/chown processing
install_paths=$(echo "${install_paths}" | tr ',' ' ')

# set permissions for container during build - Do NOT double quote variable for install_paths otherwise this will wrap space separated paths as a single string
chmod -R 775 ${install_paths}

# In install.sh heredoc, replace the chown section:
cat <<EOF > /tmp/permissions_heredoc
install_paths="${install_paths}"
EOF

# replace permissions placeholder string with contents of file (here doc)
sed -i '/# PERMISSIONS_PLACEHOLDER/{
    s/# PERMISSIONS_PLACEHOLDER//g
    r /tmp/permissions_heredoc
}' /usr/bin/init.sh
rm /tmp/permissions_heredoc

# cleanup
cleanup.sh
