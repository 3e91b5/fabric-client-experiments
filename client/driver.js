import { Gateway, Wallets } from 'fabric-network';
import fs from 'fs';
import path from 'path';

const ccpPath = path.resolve(
  '..', 'test-network', 'organizations', 'peerOrganizations',
  'org1.example.com', 'connection-org1.json');
const ccp = JSON.parse(fs.readFileSync(ccpPath, 'utf8'));

const run = async () => {
  const wallet = await Wallets.newFileSystemWallet('./wallet');
  const identity = await wallet.get('appUser');
  if (!identity) {
    console.log('✗ appUser identity not found. Enroll first.'); return;
  }

  const gateway = new Gateway();
  await gateway.connect(ccp, {
    wallet,
    identity: 'appUser',
    discovery: { enabled: true, asLocalhost: true }
  });

  const network = await gateway.getNetwork('mychannel');
  const contract = network.getContract('token');

  // 블록 이벤트 리스너
  const listener = async (event) => {
    console.log(`✔︎ Block ${event.blockNumber} committed`);
  };
  await network.addBlockListener(listener);

  // 매 라운드마다 10 tx 전송
  for (let round = 0; round < 20; round++) {
    const txs = [];
    for (let i = 0; i < 2; i++) {
      const from = `addr${String(Math.floor(Math.random() * 100)).padStart(3, '0')}`;
      let to;
      do { to = `addr${String(Math.floor(Math.random() * 100)).padStart(3, '0')}`; }
      while (to === from);

      const amt = Math.floor(Math.random() * 20) + 1;
      txs.push(contract.submitTransaction('Transfer', from, to, amt));
    }

    // const used = new Set();
    // while (used.size < 3) {
    //   // const from = randAddr();
    //   const from  = `addr${String(Math.floor(Math.random() * 100)).padStart(3, '0')}`;
    //   if (used.has(from)) {continue};
    //   let to;
    //   do { 
    //     to = `addr${String(Math.floor(Math.random() * 100)).padStart(3, '0')}`;
    //   } while (to === from);
    //   used.add(from);
    //   const amt = Math.floor(Math.random() * 20) + 1;
    //   console.log(`from: ${from}, to: ${to}, amt: ${amt}`);
    //   txs.push(contract.submitTransaction('Transfer', from, to, amt));
    // }

    try {
      await Promise.all(txs);      // 10 건 발송 → orderer가 한 블록으로 컷팅
    } catch (e){
      console.log('✗ Failed to send transactions');
      console.log(e);
      return;
    }
    console.log(`▲ Round ${round + 1} submitted (10 tx)`);
  }

  gateway.disconnect();
};
run();

