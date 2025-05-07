#!/usr/bin/env bash
set -e

PATTERN=$1; shift
PEER=peer0.org1.example.com
DB=/var/hyperledger/production/ledgersData/stateLeveldb
LOG=ws-${PATTERN}-$(date +%Y%m%d%H%M).csv

# --- move into test-network so envVar.sh paths are correct ---
SCRIPTDIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cd "$SCRIPTDIR/../test-network"

function du_bytes() { docker exec $PEER du -sb $DB | cut -f1; }

source scripts/envVar.sh
setGlobals 1                     # Org1 peer0

echo "pattern,count,before,after" > "$SCRIPTDIR/$LOG"

for CNT in "$@"; do
  BEFORE=$(du_bytes)

  echo "→ inserting $CNT items ($PATTERN)…"
  peer chaincode invoke \
    -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com \
    --tls --cafile "$ORDERER_CA" \
    -C mychannel -n itemcc \
    -c "{\"Args\":[\"InitBulk\",\"$CNT\",\"$PATTERN\"]}" >/dev/null

  sleep 2
  AFTER=$(du_bytes)
  echo "${PATTERN},${CNT},${BEFORE},${AFTER}" | tee -a "$SCRIPTDIR/$LOG"
done
