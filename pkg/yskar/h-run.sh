#!/usr/bin/env bash
# Startet je Grafikkarte einen Miner-Prozess. Der Miner bedient genau eine
# Karte (--device n); mehrere Prozesse auf dieselbe Adresse sind vom Projekt
# ausdruecklich vorgesehen. Die Dev-Fee steckt im Miner selbst -- hier gibt
# es dafuer keinen Schalter und keine Adresse.

cd "$(dirname "$(readlink -f "$0")")" || exit 1
. ./h-manifest.conf

# ---- Self-update: check the newest release once per start -----------------
# The agent only downloads a custom miner on first install, so a flight
# sheet re-select pulls nothing. Every miner start runs this script, and
# every start is a chance to catch up: read the latest release tag from
# the redirect (no API rate limit), and on a mismatch download and
# extract the package over this directory, then restart into it.
DIR="$PWD"
if [[ ${YSKAR_UPDATED:-} != 1 ]]; then
  neueste=$(curl -sm 10 -o /dev/null -w '%{redirect_url}' \
    https://github.com/derhier/yskar-hiveos/releases/latest 2>/dev/null \
    | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+$' | head -1 | tr -d v)
  if [[ -n $neueste && $neueste != "$CUSTOM_VERSION" ]]; then
    echo "Update available: $neueste (installed: $CUSTOM_VERSION) — downloading"
    paket="$DIR/.update.tar.gz"
    if curl -sm 120 -L -o "$paket" \
         https://github.com/derhier/yskar-hiveos/releases/latest/download/yskar.tar.gz \
       && tar tzf "$paket" 2>/dev/null | grep -q '^yskar/h-manifest.conf$'; then
      tar xzf "$paket" -C "$DIR" --strip-components=1
      rm -f "$paket"
      echo "Update installed — restarting the miner"
      YSKAR_UPDATED=1 exec "$0"
    else
      echo "Update download failed — continuing with $CUSTOM_VERSION"
      rm -f "$paket"
    fi
  fi
fi

conf() { sed -n "s/^$1=//p" "$CUSTOM_CONFIG_FILENAME" 2>/dev/null | tail -1; }
ADDRESS="$(conf ADDRESS)"; API="$(conf API)"; MODE="$(conf MODE)"
GPUS="$(conf GPUS)"; EXTRA="$(conf EXTRA)"

if [[ -z $ADDRESS || -z $API ]]; then
  echo "Missing address or pool URL — check the flight sheet ($CUSTOM_CONFIG_FILENAME)"
  sleep 30; exit 1
fi

DIR="$PWD"
MINER="$DIR/miner/yskar-miner"
CUDA="$DIR/miner/gpu/yskar-cuda"
chmod +x "$MINER" "$CUDA" 2>/dev/null
mkdir -p "$(dirname "$CUSTOM_LOG_BASENAME")"

# Gleiche Reihenfolge wie HiveOS (nach PCI-Bus).
export CUDA_DEVICE_ORDER=PCI_BUS_ID

anzahl=$("$CUDA" --probe 2>/dev/null | grep -c '"t":"device"')
if (( anzahl == 0 )); then
  echo "No NVIDIA card found:"; "$CUDA" --probe
  sleep 30; exit 1
fi

if [[ -z $GPUS || $GPUS == all ]]; then
  liste=$(seq 0 $((anzahl - 1)))
else
  liste=$(echo "$GPUS" | tr ',' ' ')
fi

rm -f "${CUSTOM_LOG_BASENAME}"_gpu*.log
echo "$(date +%s)" > "$DIR/.gestartet"

args=(--pool "$API" --gpu-bin "$CUDA")
# shellcheck disable=SC2206
[[ -n $EXTRA ]] && args+=($EXTRA)
modus=()
[[ $MODE == pool ]] && modus=(--mode pool)

kinder=()
# Erst die Miner unter den Schleifen beenden (Signale reichen weiter),
# dann die Schleifen selbst.
ende() {
  trap - INT TERM EXIT
  for k in "${kinder[@]}"; do pkill -P "$k" 2>/dev/null; done
  kill "${kinder[@]}" 2>/dev/null; pkill -P $$ 2>/dev/null; exit 0
}
trap ende INT TERM EXIT

echo "YSKAR $CUSTOM_VERSION · $anzahl card(s) · mode $MODE · $API"
for n in $liste; do
  [[ $n =~ ^[0-9]+$ ]] && (( n < anzahl )) || { echo "GPU $n does not exist, skipped"; continue; }
  (
    cd "$DIR/miner" || exit 1
    # Endet der Miner (Pool nicht erreichbar, Karte ausgefallen), nach
    # 15 Sekunden neu starten -- nur diese Karte, die anderen laufen weiter.
    while true; do
      "$MINER" --address "$ADDRESS" "${args[@]}" "${modus[@]}" --device "$n" </dev/null 2>&1 \
        | while IFS= read -r z; do
            printf '%s\n' "$z" >> "${CUSTOM_LOG_BASENAME}_gpu$n.log"
            printf '[GPU %s] %s\n' "$n" "$z"
          done
      echo "[GPU $n] miner exited — restarting in 15 s" | tee -a "${CUSTOM_LOG_BASENAME}_gpu$n.log"
      sleep 15
    done
  ) &
  kinder+=($!)
  sleep 1
done

wait
