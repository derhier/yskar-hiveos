#!/usr/bin/env bash
# Wird vom HiveOS-Agenten eingelesen (source) und muss $khs und $stats setzen.
# Quelle sind die Logs je Karte: Der Miner schreibt einmal je Minute
#   [12:00:00] 10s 3,52 GH/s 60s 3,51 GH/s 15m 3,50 GH/s · ...
# und je Share eine Zeile "angenommen #n" bzw. "abgelehnt <grund>".

. /hive/miners/custom/yskar/h-manifest.conf 2>/dev/null \
  || . "$(dirname "${BASH_SOURCE[0]}")/h-manifest.conf"
YSKAR_DIR="$(dirname "$CUSTOM_CONFIG_FILENAME")"

jetzt=$(date +%s)
hs_json="[]"; bus_json="[]"; temp_json="[]"; fan_json="[]"
acc=0; rej=0; summe_mhs=0

# Temperatur, Luefter und Bus der NVIDIA-Karten, in HiveOS-Reihenfolge.
GS="${GPU_STATS_JSON:-/run/hive/gpu-stats.json}"
if [[ -r $GS ]]; then
  readarray -t nv < <(jq -r '[.brand, .busids, .temp, .fan] | transpose[] | select(.[0]=="nvidia") | "\(.[1]) \(.[2]) \(.[3])"' "$GS" 2>/dev/null)
fi

for log in $(ls "${CUSTOM_LOG_BASENAME}"_gpu*.log 2>/dev/null | sort -V); do
  n="${log##*_gpu}"; n="${n%.log}"
  alter=$(( jetzt - $(stat -c %Y "$log") ))
  mhs=0
  if (( alter < 180 )); then
    # Wert in H/s -- der Agent kennt laut offiziellem Contract nur "hs"
    # (siehe hiveos-linux/hive/miners/*/h-stats.sh), keine abgeleiteten Einheiten.
    mhs=$(tac "$log" | grep -m1 -E '\] 10s ' | awk '{
      for (i = 1; i <= NF; i++) if ($i == "10s") { v = $(i+1); u = $(i+2); break }
      gsub(/\./, "", v); sub(/,/, ".", v)
      f = 0
      if (u == "H/s") f = 1; else if (u == "kH/s") f = 1e3; else if (u == "MH/s") f = 1e6
      else if (u == "GH/s") f = 1e9; else if (u == "TH/s") f = 1e12
      printf "%.2f", v * f }')
    [[ -z $mhs ]] && mhs=0
  fi
  a=$(grep -c ' angenommen #' "$log"); r=$(grep -c ' abgelehnt ' "$log")
  acc=$(( acc + a )); rej=$(( rej + r ))
  summe_mhs=$(awk -v x="$summe_mhs" -v y="$mhs" 'BEGIN { printf "%.2f", x + y }')
  hs_json=$(jq -c --argjson v "$mhs" '. + [$v]' <<< "$hs_json")

  read -r bus t f <<< "${nv[$n]}"
  busnr=0; [[ $bus =~ ^([0-9a-fA-F]{2}): ]] && busnr=$(( 16#${BASH_REMATCH[1]} ))
  bus_json=$(jq -c --argjson v "$busnr" '. + [$v]' <<< "$bus_json")
  temp_json=$(jq -c --argjson v "${t:-0}" '. + [$v]' <<< "$temp_json")
  fan_json=$(jq -c --argjson v "${f:-0}" '. + [$v]' <<< "$fan_json")
done

uptime=0
[[ -r $YSKAR_DIR/.gestartet ]] && uptime=$(( jetzt - $(< "$YSKAR_DIR/.gestartet") ))

khs=$(awk -v x="$summe_mhs" 'BEGIN { printf "%.0f", x / 1000 }')
stats=$(jq -nc \
  --argjson hs "$hs_json" --argjson temp "$temp_json" --argjson fan "$fan_json" \
  --argjson bus "$bus_json" --argjson uptime "$uptime" \
  --argjson acc "$acc" --argjson rej "$rej" --arg ver "$CUSTOM_VERSION" \
  '{hs: $hs, hs_units: "hs", temp: $temp, fan: $fan, uptime: $uptime,
    ver: $ver, ar: [$acc, $rej], algo: "sha256d", bus_numbers: $bus}')
