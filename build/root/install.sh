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
pacman_packages="git python python-pip xclip rsync"

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

# source in utility functions, need process_env_var
source utils.sh

# Define environment variables to process
# Format: "VAR_NAME:DEFAULT_VALUE:REQUIRED:MASK"
env_vars=(
	"CERT_PATH::false:false"
	"CERT_KEY_PATH::false:false"
	"SELF_SIGNED_CERT:no:false:false"
	"BIND_CLOUD_NAME::false:false"
	"ENABLE_STARTUP_SCRIPTS:no:false:false"
	"STARTUP_SCRIPTS_MODE:wait:false:false"
)

# Process each environment variable
for env_var in "${env_vars[@]}"; do
	IFS=':' read -r var_name default_value required mask_value <<< "${env_var}"
	process_env_var "${var_name}" "${default_value}" "${required}" "${mask_value}"
done

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
EOF

# replace env vars placeholder string with contents of file (here doc)
sed -i '/# ENVVARS_PLACEHOLDER/{
    s/# ENVVARS_PLACEHOLDER//g
    r /tmp/envvars_heredoc
}' /usr/bin/init.sh
rm /tmp/envvars_heredoc

cat <<'EOF' > /tmp/config_heredoc

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
