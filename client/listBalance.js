import { Gateway, Wallets } from 'fabric-network';
import fs from 'fs';
import path from 'path';

async function main() {
  // 네트워크 연결 정보(JSON)
  const ccpPath = path.resolve(
    '..', 'test-network', 'organizations', 'peerOrganizations',
    'org1.example.com', 'connection-org1.json');
  const ccp = JSON.parse(fs.readFileSync(ccpPath, 'utf8'));

  // 지갑·아이덴티티
  const wallet = await Wallets.newFileSystemWallet('./wallet');
  const identity = await wallet.get('appUser');
  if (!identity) { console.error('✗ appUser identity not found'); return; }

  // 게이트웨이 연결
  const gateway = new Gateway();
  await gateway.connect(ccp, {
    wallet, identity: 'appUser',
    discovery: { enabled: true, asLocalhost: true }
  });

  const network = await gateway.getNetwork('mychannel');
  const contract = network.getContract('token');

  // addr000 ~ addr099 조회
  for (let i = 0; i < 200; i++) {
    const addr = `addr${String(i).padStart(3, '0')}`;
    const result = await contract.evaluateTransaction('BalanceOf', addr);
    console.log(addr, '→', result.toString());
  }

  gateway.disconnect();
}

main().catch(console.error);
