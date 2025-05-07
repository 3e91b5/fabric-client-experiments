#!/usr/bin/env bash


set -euo pipefail

FABRIC_HOME=$HOME/hyperledgerfabric/fabric-samples
ITEMCC_DIR=$FABRIC_HOME/itemcc-go
CLIENT_DIR=$FABRIC_HOME/client
TESTNET_DIR=$FABRIC_HOME/test-network
PEER=peer0.org1.example.com
DB=/var/hyperledger/production/ledgersData/stateLeveldb


TIMESTAMP=$(date +%Y%m%d%H%M%S)
CSV_DIR=$CLIENT_DIR/csv

cd "$TESTNET_DIR"
source scripts/envVar.sh

export OVERRIDE_ORG=""
export VERBOSE=false

export FABRIC_CFG_PATH=$PWD/../config 
setGlobals 1          # CORE_PEER_* / ORDERER_CA ready






# get keys


# peer chaincode query \
# -o localhost:7050 \
# --ordererTLSHostnameOverride orderer.example.com \
# -C mychannel \
# -n itemcc \
# -c "{\"Args\":[\"GetKeys\", 10]}" \
# --tls --cafile $ORDERER_CA > "$CLIENT_DIR/keyvalues.txt"

# peer chaincode invoke \
#   -C mychannel \
#   -n itemcc \
#   -c '{"Args":["GetAllKeys","seq"]}' \
#   --tls --cafile $ORDERER_CA >/dev/null


# get all keys

peer chaincode query \
-o localhost:7050 \
--ordererTLSHostnameOverride orderer.example.com \
-C mychannel \
-n itemcc \
-c "{\"Args\":[\"GetAllKeys\"]}" \
--tls --cafile $ORDERER_CA > "$CLIENT_DIR/keyvalues.txt"