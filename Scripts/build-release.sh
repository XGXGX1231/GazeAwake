#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
DERIVED_DATA="${ROOT}/work/DerivedData"

xcodebuild \
  -project "${ROOT}/GazeAwake.xcodeproj" \
  -scheme GazeAwake \
  -configuration Release \
  -destination "platform=macOS,arch=$(uname -m)" \
  -derivedDataPath "${DERIVED_DATA}" \
  build

print "Built: ${DERIVED_DATA}/Build/Products/Release/GazeAwake.app"
