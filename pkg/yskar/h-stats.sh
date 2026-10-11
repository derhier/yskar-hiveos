#!/usr/bin/env bash
# Sourced by the HiveOS agent; must set $khs and $stats.
# Source are the per-card logs: the miner writes once per minute
#   [12:00:00] 10s 3.52 GH/s 60s 3.51 GH/s 15m 3.50 GH/s · ...
# and one line per share: "accepted #n" or "rejected <reason>".

. /hive/miners/custom/yskar/h-manifest.conf 2>/dev/null \
  || . "$(dirname "${BASH_SOURCE[0]}")/h-manifest.conf"
YSKAR_DIR="$(dirname "$CUSTOM_CONFIG_FILENAME")"

now=$(date +%s)
hs_json="[]"; bus_json="[]"; temp_json="[]"; fan_json="[]"
acc=0; rej=0; total=0

# Temperature, fan and bus of the NVIDIA cards, in HiveOS order.
GS="${GPU_STATS_JSON:-/run/hive/gpu-stats.json}"
if [[ -r $GS ]]; then
  readarray -t nv < <(jq -r '[.brand, .busids, .temp, .fan] | transpose[] | select(.[0]=="nvidia") | "\(.[1]) \(.[2]) \(.[3])"' "$GS" 2>/dev/null)
fi

for log in $(ls "${CUSTOM_LOG_BASENAME}"_gpu*.log 2>/dev/null | sort -V); do
  n="${log##*_gpu}"; n="${n%.log}"
  age=$(( now - $(stat -c %Y "$log") ))
  hps=0
  if (( age < 180 )); then
    # Value in H/s -- per the official contract the agent only knows "hs"
    # (see hiveos-linux/hive/miners/*/h-stats.sh), no derived units.
    hps=$(tac "$log" | grep -m1 -E '\] 10s ' | awk '{
      for (i = 1; i <= NF; i++) if ($i == "10s") { v = $(i+1); u = $(i+2); break }
      gsub(/,/, "", v)
      f = 0
      if (u == "H/s") f = 1; else if (u == "kH/s") f = 1e3; else if (u == "MH/s") f = 1e6
      else if (u == "GH/s") f = 1e9; else if (u == "TH/s") f = 1e12
      printf "%.2f", v * f }')
    [[ -z $hps ]] && hps=0
  fi
  a=$(grep -c ' accepted #' "$log"); r=$(grep -c ' rejected ' "$log")
  acc=$(( acc + a )); rej=$(( rej + r ))
  total=$(awk -v x="$total" -v y="$hps" 'BEGIN { printf "%.2f", x + y }')
  hs_json=$(jq -c --argjson v "$hps" '. + [$v]' <<< "$hs_json")

  read -r bus t f <<< "${nv[$n]}"
  busnr=0; [[ $bus =~ ^([0-9a-fA-F]{2}): ]] && busnr=$(( 16#${BASH_REMATCH[1]} ))
  bus_json=$(jq -c --argjson v "$busnr" '. + [$v]' <<< "$bus_json")
  temp_json=$(jq -c --argjson v "${t:-0}" '. + [$v]' <<< "$temp_json")
  fan_json=$(jq -c --argjson v "${f:-0}" '. + [$v]' <<< "$fan_json")
done

uptime=0
[[ -r $YSKAR_DIR/.gestartet ]] && uptime=$(( now - $(< "$YSKAR_DIR/.gestartet") ))

khs=$(awk -v x="$total" 'BEGIN { printf "%.0f", x / 1000 }')
stats=$(jq -nc \
  --argjson hs "$hs_json" --argjson temp "$temp_json" --argjson fan "$fan_json" \
  --argjson bus "$bus_json" --argjson uptime "$uptime" \
  --argjson acc "$acc" --argjson rej "$rej" --arg ver "$CUSTOM_VERSION" \
  '{hs: $hs, hs_units: "hs", temp: $temp, fan: $fan, uptime: $uptime,
    ver: $ver, ar: [$acc, $rej], algo: "sha256d", bus_numbers: $bus}')
