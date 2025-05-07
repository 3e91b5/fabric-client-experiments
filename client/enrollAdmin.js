import FabricCAServices from 'fabric-ca-client';
import { Wallets } from 'fabric-network';
import fs from 'fs';
import path from 'path';

async function main() {
  const ccpPath = path.resolve(
    '..', 'test-network', 'organizations',
    'peerOrganizations', 'org1.example.com', 'connection-org1.json');
  const ccp = JSON.parse(fs.readFileSync(ccpPath, 'utf8'));

  const caInfo = ccp.certificateAuthorities['ca.org1.example.com'];
  const ca = new FabricCAServices(caInfo.url,
      { trustedRoots: caInfo.tlsCACerts.pem, verify: false },
      caInfo.caName);

  const wallet = await Wallets.newFileSystemWallet('./wallet');
  if (await wallet.get('admin')) { console.log('✔︎ admin already enrolled'); return; }

  const enrollment = await ca.enroll({ enrollmentID: 'admin', enrollmentSecret: 'adminpw' });
  await wallet.put('admin', {
    credentials: { certificate: enrollment.certificate, privateKey: enrollment.key.toBytes() },
    mspId: 'Org1MSP', type: 'X.509'
  });
  console.log('✅ Successfully enrolled admin and imported to wallet');
}
main();

