const fetch = require('node-fetch');

async function addStreamingUrlsToTest3() {
  const testData = {
    title: "Test3",
    animeName: "青の箱",
    duration: "4時間",
    description: "テスト",
    spots: [],
    price: 200,
    tags: [],
    imageUrl: "",
    thumbnailUrl: "",
    numberOfDays: 1,
    streamingUrls: [
      { name: "Netflix", url: "https://netflix.com/aonobox" },
      { name: "U-NEXT", url: "https://video.unext.jp/freeword?query=%E9%9D%92%E3%81%AE%E7%AE%B1&td=SID0157094" }
    ]
  };

  console.log('📤 Test3プランにストリーミングURLを追加中...');

  try {
    const response = await fetch('http://localhost:5002/api/travel-plans/dct47Qm3Mi9X6wCondSE', {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(testData),
    });

    if (response.ok) {
      const result = await response.json();
      console.log('✅ Test3プランが更新されました!');
      console.log('streamingUrls:', result.streamingUrls);
    } else {
      const error = await response.text();
      console.error('❌ 更新失敗:', error);
    }
  } catch (error) {
    console.error('❌ エラー:', error.message);
  }
}

addStreamingUrlsToTest3();