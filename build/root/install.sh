#!/bin/bash

# exit script if return code != 0
set -e

# release tag name from build arg, stripped of build ver using string manipulation
release_tag_name="${1//-[0-9][0-9]/}"

# build scripts
####

# download build scripts from github
curl --connect-timeout 5 --max-time 600 --retry 5 --retry-delay 0 --retry-max-time 60 -o /tmp/scripts-master.zip -L https://github.com/binhex/scripts/archive/master.zip

# unzip build scripts
unzip /tmp/scripts-master.zip -d /tmp

# move shell scripts to /root
mv /tmp/scripts-master/shell/arch/docker/*.sh /usr/local/bin/

# detect image arch
####

OS_ARCH=$(grep -P -o -m 1 "(?=^ID\=).*" < '/etc/os-release' | grep -P -o -m 1 "[a-z]+$")
if [[ ! -z "${OS_ARCH}" ]]; then
	if [[ "${OS_ARCH}" == "arch" ]]; then
		OS_ARCH="x86-64"
	else
		OS_ARCH="aarch64"
	fi
	echo "[info] OS_ARCH defined as '${OS_ARCH}'"
else
	echo "[warn] Unable to identify OS_ARCH, defaulting to 'x86-64'"
	OS_ARCH="x86-64"
fi

# pacman packages
####

# define pacman packages
pacman_packages="git python python-pip openssl-1.1"

# install compiled packages using pacman
if [[ ! -z "${pacman_packages}" ]]; then
	pacman -S --needed ${pacman_packages} --noconfirm
fi

# aur packages
####

# define aur packages
aur_packages="code-server code-marketplace"

# call aur install script (arch user repo)
source aur.sh

# custom
####

# replace nasty web icon with ms version
cp -f '/home/nobody/icons/favicon'* '/usr/lib/code-server/src/browser/media/'
cp -f '/usr/lib/code-server/src/browser/media/favicon.svg' '/usr/lib/code-server/src/browser/media/favicon-dark-support.svg'

package_name="python2.tar.zst"

# download compiled python2 (removed from AOR)
rcurl.sh -o "/tmp/${package_name}" "https://github.com/binhex/packages/raw/master/compiled/${OS_ARCH}/${package_name}"

# install python2
pacman -U "/tmp/${package_name}" --noconfirm

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
}' /usr/local/bin/init.sh
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
symlink --src-path '/home/nobody' --dst-path '/config/home' --link-type 'softlink' --log-level 'WARN'
EOF

# replace config placeholder string with contents of file (here doc)
sed -i '/# CONFIG_PLACEHOLDER/{
    s/# CONFIG_PLACEHOLDER//g
    r /tmp/config_heredoc
}' /usr/local/bin/init.sh
rm /tmp/config_heredoc

# container perms
####

# create path to store temporary files
mkdir -p '/usr/lib/code'

# define comma separated list of paths
install_paths="/home/nobody,/usr/lib/code"

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

# create file with contents of here doc, note EOF is NOT quoted to allow us to expand current variable 'install_paths'
# we use escaping to prevent variable expansion for PUID and PGID, as we want these expanded at runtime of init.sh
cat <<EOF > /tmp/permissions_heredoc

# get previous puid/pgid (if first run then will be empty string)
previous_puid=\$(cat "/root/puid" 2>/dev/null || true)
previous_pgid=\$(cat "/root/pgid" 2>/dev/null || true)

# if first run (no puid or pgid files in /tmp) or the PUID or PGID env vars are different
# from the previous run then re-apply chown with current PUID and PGID values.
if [[ ! -f "/root/puid" || ! -f "/root/pgid" || "\${previous_puid}" != "\${PUID}" || "\${previous_pgid}" != "\${PGID}" ]]; then

	# set permissions inside container - Do NOT double quote variable for install_paths otherwise this will wrap space separated paths as a single string
	chown -R "\${PUID}":"\${PGID}" ${install_paths}

fi

# write out current PUID and PGID to files in /root (used to compare on next run)
echo "\${PUID}" > /root/puid
echo "\${PGID}" > /root/pgid

EOF

# replace permissions placeholder string with contents of file (here doc)
sed -i '/# PERMISSIONS_PLACEHOLDER/{
    s/# PERMISSIONS_PLACEHOLDER//g
    r /tmp/permissions_heredoc
}' /usr/local/bin/init.sh
rm /tmp/permissions_heredoc

# cleanup
cleanup.sh
