#!/usr/bin/env bash
# Startet je Grafikkarte einen Miner-Prozess. Der CLI-Miner bedient genau
# eine Karte (--device n); mehrere Prozesse auf dieselbe Adresse sind vom
# Projekt ausdruecklich vorgesehen.

cd "$(dirname "$(readlink -f "$0")")" || exit 1
. ./h-manifest.conf

conf() { sed -n "s/^$1=//p" "$CUSTOM_CONFIG_FILENAME" 2>/dev/null | tail -1; }
ADDRESS="$(conf ADDRESS)"; API="$(conf API)"; MODE="$(conf MODE)"
GPUS="$(conf GPUS)"; EXTRA="$(conf EXTRA)"

if [[ -z $ADDRESS || -z $API ]]; then
  echo "Adresse oder Pool URL fehlt -- Flightsheet pruefen ($CUSTOM_CONFIG_FILENAME)"
  sleep 30; exit 1
fi

DIR="$PWD"
NODE="$DIR/node/bin/node"
CUDA="$DIR/miner/gpu/yskar-cuda"
chmod +x "$NODE" "$CUDA" 2>/dev/null
mkdir -p "$(dirname "$CUSTOM_LOG_BASENAME")"

# Gleiche Reihenfolge wie HiveOS (nach PCI-Bus).
export CUDA_DEVICE_ORDER=PCI_BUS_ID
export NO_COLOR=1

anzahl=$("$CUDA" --probe 2>/dev/null | grep -c '"t":"device"')
if (( anzahl == 0 )); then
  echo "Keine NVIDIA-Karte gefunden:"; "$CUDA" --probe
  sleep 30; exit 1
fi

if [[ -z $GPUS || $GPUS == all ]]; then
  liste=$(seq 0 $((anzahl - 1)))
else
  liste=$(echo "$GPUS" | tr ',' ' ')
fi

rm -f "${CUSTOM_LOG_BASENAME}"_gpu*.log
date +%s > "$DIR/.gestartet"

args=(--address "$ADDRESS" --api "$API" --gpu --gpu-bin "$CUDA" --einfach)
[[ $MODE == pool ]] && args+=(--mode pool)
# shellcheck disable=SC2206
[[ -n $EXTRA ]] && args+=($EXTRA)

kinder=()
ende() { trap - INT TERM EXIT; kill "${kinder[@]}" 2>/dev/null; pkill -P $$ 2>/dev/null; exit 0; }
trap ende INT TERM EXIT

echo "YSKAR $CUSTOM_VERSION · $anzahl Karte(n) · Modus $MODE · $API"
for n in $liste; do
  [[ $n =~ ^[0-9]+$ ]] && (( n < anzahl )) || { echo "GPU $n gibt es nicht, uebersprungen"; continue; }
  (
    cd "$DIR/miner" || exit 1
    # Endet der Miner (Pool nicht erreichbar, Karte ausgefallen), nach
    # 15 Sekunden neu starten -- nur diese Karte, die anderen laufen weiter.
    while true; do
      "$NODE" src/cli.mjs "${args[@]}" --device "$n" </dev/null 2>&1 \
        | while IFS= read -r z; do
            printf '%s\n' "$z" >> "${CUSTOM_LOG_BASENAME}_gpu$n.log"
            printf '[GPU %s] %s\n' "$n" "$z"
          done
      echo "[GPU $n] Miner beendet -- Neustart in 15 s" | tee -a "${CUSTOM_LOG_BASENAME}_gpu$n.log"
      sleep 15
    done
  ) &
  kinder+=($!)
  sleep 1
done

wait
