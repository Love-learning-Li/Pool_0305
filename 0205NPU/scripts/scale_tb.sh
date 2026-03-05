#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <CHin> <Hin> <Win> [Kx Ky Sx Sy Px Py]"
  exit 1
fi

CHIN="$1"
HIN="$2"
WIN="$3"
KX="${4:-3}"
KY="${5:-3}"
SX="${6:-1}"
SY="${7:-1}"
PX="${8:-1}"
PY="${9:-1}"

TB="/home/zth/sppf_verilog/0205NPU/tb/testbench_POOL.sv"

tmp="$(mktemp)"
awk -v WIN="$WIN" -v HIN="$HIN" -v CHIN="$CHIN" \
    -v KX="$KX" -v KY="$KY" -v SX="$SX" -v SY="$SY" \
    -v PX="$PX" -v PY="$PY" '
  /^`define Win/  {print "`define Win               " WIN;  next}
  /^`define Hin/  {print "`define Hin               " HIN;  next}
  /^`define CHin/ {print "`define CHin              " CHIN; next}
  /^`define Ky/   {print "`define Ky                " KY;   next}
  /^`define Kx/   {print "`define Kx                " KX;   next}
  /^`define Sy/   {print "`define Sy                " SY;   next}
  /^`define Sx/   {print "`define Sx                " SX;   next}
  /^`define Py/   {print "`define Py                " PY;   next}
  /^`define Px/   {print "`define Px                " PX;   next}
  {print}
' "$TB" > "$tmp"

mv "$tmp" "$TB"
echo "Updated: CHin=${CHIN} Hin=${HIN} Win=${WIN} Kx=${KX} Ky=${KY} Sx=${SX} Sy=${SY} Px=${PX} Py=${PY}"
