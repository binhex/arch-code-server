#!/usr/bin/dumb-init /bin/bash

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

# -v option means confirm env var keyname exists, does not confirm if value is empty or not
if [[ -v 'ENABLE_MS_EXTENSIONS_GALLERY' ]]; then

    vscode_product_filepath='/usr/lib/code-server/lib/vscode/product.json'
    echo "[warn] Microsoft Extensions Gallery enabled via env var 'ENABLE_MS_EXTENSIONS_GALLERY', please ensure you are not violating any rules!."

    if ! grep -q 'extensionsGallery' "${vscode_product_filepath}"; then

        echo "[info] Microsoft Extensions Gallery not found, inserting into '${vscode_product_filepath}'..."

sed -i 's~  "quality": "stable",~  "extensionsGallery": {\
    "serviceUrl": "https://marketplace.visualstudio.com/_apis/public/gallery",\
    "cacheUrl": "https://vscode.blob.core.windows.net/gallery/index",\
    "itemUrl": "https://marketplace.visualstudio.com/items"\
  },\
  "quality": "stable",~g' "${vscode_product_filepath}"

    fi

fi

# /usr/bin/code-server = run code-server in foreground (blocking)
# --host 0.0.0.0 = set host to all ip's - see https://github.com/coder/code-server/issues/4443#issuecomment-2129423659
# --trusted-origins=* = trust all origins - see https://github.com/coder/code-server/issues/4443#issuecomment-2129423659
# --disable-telemetry = disable telemetry
# --disable-update-check = disable updates
# --bind-addr 0.0.0.0:8500 = bind to all ip's
# "${link}" = variable to define cloud cdr instance name
# "${cert}" = variable to define custom cert path, or if no path specified then self-signed cert generated
# "${cert_key}" = variable to define custom cert key path, or if no path specified then self-signed cert generated
# --config '/config/code-server/config/config.yml' = filepath to config file (contains password amongst other things)
# --user-data-dir '/config/code-server/user-data' = define path to store user data
# --extensions-dir '/config/code-server/extensions' = define path to store extensions
/usr/bin/code-server --host 0.0.0.0 --trusted-origins=* --disable-telemetry --disable-update-check --bind-addr 0.0.0.0:8500 ${link} ${cert} ${cert_key} --config '/config/code-server/config/config.yml' --user-data-dir '/config/code-server/user-data' --extensions-dir '/config/code-server/extensions'
