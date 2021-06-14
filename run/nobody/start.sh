#!/bin/bash

# /usr/bin/code-server = run code-server in foreground (blocking)
# --disable-telemetry = disable telemetry
# --disable-update-check = disable updates
# --bind-addr 0.0.0.0:8500 = bind to all ip's
# --cert = generate self-signed cert
# -config '/config/code-server/config/config.yml' = filepath to config file (contains password amongst other things)
# --user-data-dir '/config/code-server/user-data' = define path to store user data
# --extensions-dir '/config/code-server/extensions' = define path to store extensions
/usr/bin/code-server --disable-telemetry --disable-update-check --bind-addr 0.0.0.0:8500 --cert --config '/config/code-server/config/config.yml' --user-data-dir '/config/code-server/user-data' --extensions-dir '/config/code-server/extensions'
