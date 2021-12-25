#!/bin/bash

# switch marketplace to microsoft (used to install extensions)
export SERVICE_URL=https://marketplace.visualstudio.com/_apis/public/gallery
export CACHE_URL=https://vscode.blob.core.windows.net/gallery/index
export ITEM_URL=https://marketplace.visualstudio.com/items

# this allows git to access docker bind mounts
export GIT_DISCOVERY_ACROSS_FILESYSTEM=1

# create folders to store workspace and certs
mkdir -p '/config/code-server/workspace/' '/config/code-server/certs/'

# read in ev vars to define cert configuration
if [[ -n "${BIND_CLOUD_NAME}" ]]; then

    link="--link ${BIND_CLOUD_NAME}"
    cert=""
    cert_key=""

else

    link=""
    if [[ -n "${CERT_PATH}" && -n "${CERT_KEY_PATH}" ]]; then

        cert="--cert ${CERT_PATH}"
        cert_key="--cert-key ${CERT_KEY_PATH}"

    elif [[ "${SELF_SIGNED_CERT}" == "yes" ]]; then

        cert="--cert"
        cert_key=""

    else

        cert=""
        cert_key=""

    fi

fi

# /usr/bin/code-server = run code-server in foreground (blocking)
# --disable-telemetry = disable telemetry
# --disable-update-check = disable updates
# --bind-addr 0.0.0.0:8500 = bind to all ip's
# "${link}" = variable to define cloud cdr instance name
# "${cert}" = variable to define custom cert path, or if no path specified then self-signed cert generated
# "${cert_key}" = variable to define custom cert key path, or if no path specified then self-signed cert generated
# --config '/config/code-server/config/config.yml' = filepath to config file (contains password amongst other things)
# --user-data-dir '/config/code-server/user-data' = define path to store user data
# --extensions-dir '/config/code-server/extensions' = define path to store extensions
/usr/bin/code-server --disable-telemetry --disable-update-check --bind-addr 0.0.0.0:8500 ${link} ${cert} ${cert_key} --config '/config/code-server/config/config.yml' --user-data-dir '/config/code-server/user-data' --extensions-dir '/config/code-server/extensions' ${code_startup}
