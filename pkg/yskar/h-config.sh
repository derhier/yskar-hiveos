#!/usr/bin/env bash
# Called by HiveOS with the flight sheet values; writes yskar.conf from them.
#   CUSTOM_TEMPLATE     wallet and worker template  -> address (ysr1...)
#   CUSTOM_URL          pool URL
#   CUSTOM_USER_CONFIG  extra config arguments      -> MODE=, GPUS=, EXTRA=

[[ -z $CUSTOM_CONFIG_FILENAME ]] && . "$(dirname "${BASH_SOURCE[0]}")/h-manifest.conf"

# The address is the part before the dot -- the template is "%WAL%.%WORKER_NAME%".
addr="${CUSTOM_TEMPLATE%%.*}"
addr="${addr//[[:space:]]/}"
api="${CUSTOM_URL//[[:space:]]/}"
api="${api%/}"

# Only take known keys from the extra config.
opt() { echo "$CUSTOM_USER_CONFIG" | tr ';' '\n' | sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*//p" | tail -1 | tr -d '"\r' | sed 's/[[:space:]]*$//'; }
mode="$(opt MODE)";   [[ $mode != solo ]] && mode=pool
gpus="$(opt GPUS)";   [[ -z $gpus ]] && gpus=all
extra="$(opt EXTRA)"

[[ $addr =~ ^ysr1[0-9a-z]{38}$ ]] || echo "WARNING: '$addr' does not look like a YSKAR address (ysr1..., 42 characters)"
[[ $api =~ ^https?:// ]] || echo "WARNING: pool URL '$api' must start with http:// or https://"

cat > "$CUSTOM_CONFIG_FILENAME" <<CONF
ADDRESS=$addr
API=$api
MODE=$mode
GPUS=$gpus
EXTRA=$extra
CONF
