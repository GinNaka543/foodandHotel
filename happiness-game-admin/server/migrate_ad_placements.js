const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function migratePlacements() {
  const adsSnapshot = await db.collection('advertisements').get();
  let updated = 0;
  for (const doc of adsSnapshot.docs) {
    const data = doc.data();
    // placement（単数）が存在し、placements（配列）が未設定の場合のみ変換
    if (data.placement && !data.placements) {
      await doc.ref.update({
        placements: [data.placement],
        placement: admin.firestore.FieldValue.delete()
      });
      updated++;
      console.log(`広告 ${doc.id} を変換しました`);
    }
    // placementsがstring型の場合も配列に変換
    if (data.placements && typeof data.placements === 'string') {
      await doc.ref.update({
        placements: [data.placements]
      });
      updated++;
      console.log(`広告 ${doc.id} のplacementsを配列に修正しました`);
    }
  }
  console.log(`変換完了: ${updated}件修正`);
  process.exit(0);
}

migratePlacements().catch(e => {
  console.error(e);
  process.exit(1);
}); 