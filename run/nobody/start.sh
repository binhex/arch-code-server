#!/bin/bash

function symlink_home_dir {

	app_name="${1}"

	# if container folder exists then rename and use as default restore
	if [[ -d "/home/nobody" && ! -L "/home/nobody" ]]; then
		echo "[info] /home/nobody folder storing user general settings already exists, renaming..."
		mv "/home/nobody" "/home/nobody-backup"
	fi

	# if /config/home doesnt exist then restore from backup (see note above)
	if [[ ! -d "/config/${app_name}/home" ]]; then
		if [[ -d "/home/nobody-backup" ]]; then
			echo "[info] /config/${app_name}/home folder storing user general settings does not exist, copying defaults..."
			mkdir -p "/config/${app_name}/home" ; cp -R "/home/nobody-backup" "/config/${app_name}/home"
		fi
	else
		echo "[info] /config/${app_name}/home folder storing user general settings already exists, skipping copy"
	fi

	# create soft link to /home/nobody/${folder} storing general settings
	echo "[info] Creating soft link from /config/${app_name}/home to /home/nobody..."
	mkdir -p "/config/${app_name}/home" ; rm -rf "/home/nobody" ; ln -s "/config/${app_name}/home/" "/home/nobody/"

}

symlink_home_dir "${code-server}"

# /usr/bin/code-server = run code-server in foreground (blocking)
# --disable-telemetry = disable telemetry
# --disable-update-check = disable updates
# --bind-addr 0.0.0.0:8500 = bind to all ip's
# --cert = generate self-signed cert
# -config '/config/code-server/config/config.yml' = filepath to config file (contains password amongst other things)
# --user-data-dir '/config/code-server/user-data' = define path to store user data
# --extensions-dir '/config/code-server/extensions' = define path to store extensions
/usr/bin/code-server --disable-telemetry --disable-update-check --bind-addr 0.0.0.0:8500 --cert --config '/config/code-server/config/config.yml' --user-data-dir '/config/code-server/user-data' --extensions-dir '/config/code-server/extensions'
