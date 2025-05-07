#!/usr/bin/env bash
# =============== reset_and_run_experiment.sh ===============
# 전체 네트워크 초기화 + 패턴별 월드스테이트 크기 실험 (du 만 측정)
# 경로 기준: fabric-samples/  (itemcc-go, test-network, client 폴더가 있어야 함)

set -euo pipefail

### 실험 파라미터 ###########################################
ROUND_STEP=10000       # 한 번에 삽입할 키 수
TOTAL=1000000           # 패턴당 총 키 수
# PATTERNS=(sequ rand hash)
PATTERNS=(sequ rand shortprefix)
##############################################################

FABRIC_HOME=$HOME/hyperledgerfabric/fabric-samples
ITEMCC_DIR=$FABRIC_HOME/itemcc-go
CLIENT_DIR=$FABRIC_HOME/client
TESTNET_DIR=$FABRIC_HOME/test-network
PEER=peer0.org1.example.com
DB=/var/hyperledger/production/ledgersData/stateLeveldb


TIMESTAMP_PREFIX=$(date +%Y%m%d_%H%M%S) # 각 패턴별 파일명에 고유한 타임스탬프를 위해 루프 밖에서 Prefix 생성
CSV_DIR=$CLIENT_DIR/csv
mkdir -p "$CSV_DIR"

du_bytes() { docker exec "$PEER" du -sb "$DB" | cut -f1; }

for PAT in "${PATTERNS[@]}"; do
  echo "===================================================================="
  echo "STARTING EXPERIMENT FOR PATTERN: ${PAT^^}"
  echo "===================================================================="

  echo "[STEP 0 - ${PAT^^}] Clean‑up old network, volumes, wallet"
  cd "$TESTNET_DIR"
  ./network.sh down || true
  rm -rf "$CLIENT_DIR/wallet" # 이전 패턴의 지갑 정보 삭제

  echo "[STEP 1 - ${PAT^^}] Network up (LevelDB) + channel"
  export IMAGE_TAG=2.5.12 # 환경 변수는 루프 내에서도 유효해야 함
  ./network.sh up -ca
  ./network.sh createChannel -c mychannel

  echo "[STEP 2 - ${PAT^^}] Deploy itemcc chaincode"
  ./network.sh deployCC -ccn itemcc -ccp "$ITEMCC_DIR" -ccl go -ccv 1.0

  echo "[STEP 3 - ${PAT^^}] Re-create wallets"
  cd "$CLIENT_DIR"
  node enrollAdmin.js
  node registerUser.js

  echo "[STEP 4 - ${PAT^^}] Load Org1 peer0 env vars"
  cd "$TESTNET_DIR"
  export OVERRIDE_ORG=""
  export VERBOSE=false
  source scripts/envVar.sh
  export FABRIC_CFG_PATH=$PWD/../config 
  setGlobals 1          # CORE_PEER_* / ORDERER_CA ready

  OFFSET=0
  # 각 패턴별 CSV 파일명에 고유한 타임스탬프 사용 (또는 PATTERN_START_SIZE 직전에 생성)
  # TIMESTAMP=$(date +%Y%m%d_%H%M%S) # 루프 안으로 이동하여 각 패턴별 파일에 다른 타임스탬프 적용
  CSV="$CSV_DIR/ws-${PAT}-${TIMESTAMP_PREFIX}-${ROUND_STEP}-${TOTAL}.csv" # Prefix 사용 또는 아래처럼 매번 생성
  # CSV="$CSV_DIR/ws-${PAT}-$(date +%Y%m%d_%H%M%S)-${ROUND_STEP}-${TOTAL}.csv"


  echo "pattern,count,before_round,after_round,round_delta,cumulative_delta_from_pattern_start" > "$CSV"
  
  # 각 패턴 시작 시의 스토리지 크기를 저장할 변수 (네트워크 재시작 후 측정)
  PATTERN_START_SIZE=$(du_bytes)

  while (( OFFSET < TOTAL )); do
    BEFORE_ROUND=$(du_bytes) # 현재 라운드 시작 전 크기
    INC=$ROUND_STEP
    echo "[${PAT^^}] offset=$OFFSET  insert=$INC"

    peer chaincode invoke -o localhost:7050 \
      --ordererTLSHostnameOverride orderer.example.com \
      --peerAddresses localhost:7051 \
      --tlsRootCertFiles organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
      --peerAddresses localhost:9051 \
      --tlsRootCertFiles organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt \
      --tls --cafile "$ORDERER_CA" \
      -C mychannel -n itemcc \
      -c "{\"Args\":[\"InitBulk\",\"$OFFSET\",\"$INC\",\"$PAT\"]}" >/dev/null

    sleep 2
    AFTER_ROUND=$(du_bytes) # 현재 라운드 종료 후 크기
    ROUND_DELTA=$(( AFTER_ROUND - BEFORE_ROUND ))
    
    CUMULATIVE_DELTA_FROM_PATTERN_START=$(( AFTER_ROUND - PATTERN_START_SIZE ))
    
    echo "${PAT},$((OFFSET+INC)),${BEFORE_ROUND},${AFTER_ROUND},${ROUND_DELTA},${CUMULATIVE_DELTA_FROM_PATTERN_START}" | tee -a "$CSV"

    OFFSET=$((OFFSET + INC))
  done
  echo "[${PAT^^}] finished → $CSV"
  echo "===================================================================="
  echo "FINISHED EXPERIMENT FOR PATTERN: ${PAT^^}"
  echo "===================================================================="
  sleep 5 # 다음 패턴 시작 전 잠시 대기 (선택 사항)
done

echo "🟢  Experiment complete!  All CSV files are in: $CSV_DIR/"