#!/bin/zsh
set -euo pipefail

DURATION="${1:-60}"
PID="${2:-$(pgrep -x GazeAwake | head -1)}"
if [[ -z "${PID}" ]]; then
  print -u2 "GazeAwake is not running. Launch the Release app first."
  exit 1
fi

print "Monitoring PID ${PID} for ${DURATION}s (2s interval)"
print "time,cpu_percent,rss_kib,physical_footprint_bytes"
end=$(( EPOCHSECONDS + DURATION ))
while (( EPOCHSECONDS < end )); do
  if ! kill -0 "${PID}" 2>/dev/null; then
    print -u2 "Process exited."
    exit 2
  fi
  cpu=$(ps -o %cpu= -p "${PID}" | xargs)
  rss=$(ps -o rss= -p "${PID}" | xargs)
  footprint_bytes=$(footprint --noCategories --format bytes "${PID}" 2>/dev/null \
    | awk '/phys_footprint:/ {gsub(/[^0-9]/, "", $2); print $2; exit}')
  print "$(date +%H:%M:%S),${cpu},${rss},${footprint_bytes:-unknown}"
  sleep 2
done
