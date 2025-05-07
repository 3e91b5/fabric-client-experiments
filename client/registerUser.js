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
  const ca = new FabricCAServices(caInfo.url, { verify: false }, caInfo.caName);

  const wallet = await Wallets.newFileSystemWallet('./wallet');
  if (await wallet.get('appUser')) { console.log('✔︎ appUser already enrolled'); return; }

  const adminIdentity = await wallet.get('admin');
  if (!adminIdentity) { console.error('✗ Enroll admin first'); return; }

  const provider = wallet.getProviderRegistry().getProvider(adminIdentity.type);
  const adminUser = await provider.getUserContext(adminIdentity, 'admin');

  const secret = await ca.register({
      affiliation: 'org1.department1',
      enrollmentID: 'appUser',
      role: 'client'
    }, adminUser);

  const enrollment = await ca.enroll({ enrollmentID: 'appUser', enrollmentSecret: secret });
  await wallet.put('appUser', {
    credentials: { certificate: enrollment.certificate, privateKey: enrollment.key.toBytes() },
    mspId: 'Org1MSP', type: 'X.509'
  });
  console.log('✅ Successfully registered and enrolled appUser');
}
main();

