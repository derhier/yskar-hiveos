#!/usr/bin/env bash
# Wird von HiveOS mit den Werten des Flightsheets aufgerufen und schreibt
# daraus yskar.conf.
#   CUSTOM_TEMPLATE     Wallet and worker template  -> Adresse (ysr1...)
#   CUSTOM_URL          Pool URL                    -> --api
#   CUSTOM_USER_CONFIG  Extra config arguments      -> MODE=, GPUS=, EXTRA=

[[ -z $CUSTOM_CONFIG_FILENAME ]] && . "$(dirname "${BASH_SOURCE[0]}")/h-manifest.conf"

# Die Adresse ist der Teil vor einem Punkt -- falls das Template "%WAL%.%WORKER_NAME%" ist.
addr="${CUSTOM_TEMPLATE%%.*}"
addr="${addr//[[:space:]]/}"
api="${CUSTOM_URL//[[:space:]]/}"
api="${api%/}"

# Nur bekannte Schluessel aus der Extra-Konfiguration uebernehmen.
opt() { echo "$CUSTOM_USER_CONFIG" | tr ';' '\n' | sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*//p" | tail -1 | tr -d '"\r' | sed 's/[[:space:]]*$//'; }
mode="$(opt MODE)";   [[ $mode != solo ]] && mode=pool
gpus="$(opt GPUS)";   [[ -z $gpus ]] && gpus=all
extra="$(opt EXTRA)"

[[ $addr =~ ^ysr1[0-9a-z]{38}$ ]] || echo "WARNUNG: '$addr' sieht nicht nach einer YSKAR-Adresse aus (ysr1..., 42 Zeichen)"
[[ $api =~ ^https?:// ]] || echo "WARNUNG: Pool URL '$api' muss mit http:// oder https:// beginnen"

cat > "$CUSTOM_CONFIG_FILENAME" <<CONF
ADDRESS=$addr
API=$api
MODE=$mode
GPUS=$gpus
EXTRA=$extra
CONF
