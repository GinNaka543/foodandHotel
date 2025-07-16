export default function Home() {
  return (
    <main className="min-h-screen">
      {/* Hero Section */}
      <section className="h-screen flex flex-col items-center justify-center px-4 text-center">
        <h1 className="text-4xl md:text-6xl font-bold mb-4">
          Happiness Game
        </h1>
        <p className="text-lg md:text-xl mb-8 max-w-2xl">
          推しとの思い出を、もっと特別に。
          キャラクターや声優の誕生日リマインダー、聖地巡礼の記録、
          大切な思い出を一つのアプリで管理。
        </p>
        <div className="flex gap-4">
          <a
            href="#features"
            className="px-8 py-3 bg-black text-white hover:bg-gray-800 transition-colors"
          >
            機能を見る
          </a>
          <a
            href="#download"
            className="px-8 py-3 border-2 border-black hover:bg-black hover:text-white transition-colors"
          >
            ダウンロード
          </a>
        </div>
      </section>

      {/* Features Section */}
      <section id="features" className="py-20 px-4">
        <div className="max-w-6xl mx-auto">
          <h2 className="text-3xl md:text-4xl font-bold text-center mb-16">
            主な機能
          </h2>
          <div className="grid md:grid-cols-3 gap-8">
            <div className="text-center p-8 border-2 border-black">
              <h3 className="text-xl font-bold mb-4">誕生日リマインダー</h3>
              <p className="text-gray-700">
                推しキャラクターや声優の誕生日を忘れずにお祝い。
                事前通知で準備も完璧に。
              </p>
            </div>
            <div className="text-center p-8 border-2 border-black">
              <h3 className="text-xl font-bold mb-4">聖地巡礼記録</h3>
              <p className="text-gray-700">
                訪れた聖地の写真や感想を記録。
                地図と連携して思い出を振り返ろう。
              </p>
            </div>
            <div className="text-center p-8 border-2 border-black">
              <h3 className="text-xl font-bold mb-4">メモリーアルバム</h3>
              <p className="text-gray-700">
                イベントやグッズの写真を整理。
                推し活の思い出を美しく保存。
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* About Section */}
      <section className="py-20 px-4 bg-black text-white">
        <div className="max-w-4xl mx-auto text-center">
          <h2 className="text-3xl md:text-4xl font-bold mb-8">
            推し活をもっと楽しく
          </h2>
          <p className="text-lg mb-8">
            Happiness Gameは、あなたの推し活をサポートするために生まれました。
            大切な日を忘れない、思い出を美しく残す、聖地巡礼を記録する。
            すべての機能が、あなたと推しとの絆を深めます。
          </p>
        </div>
      </section>

      {/* Download Section */}
      <section id="download" className="py-20 px-4">
        <div className="max-w-4xl mx-auto text-center">
          <h2 className="text-3xl md:text-4xl font-bold mb-8">
            今すぐダウンロード
          </h2>
          <p className="text-lg mb-8">
            iOS版が利用可能です。App Storeからダウンロードして、
            推し活をもっと充実させましょう。
          </p>
          <a
            href="#"
            className="inline-block px-12 py-4 bg-black text-white text-lg hover:bg-gray-800 transition-colors"
          >
            App Storeで入手
          </a>
        </div>
      </section>

      {/* Footer */}
      <footer className="py-8 px-4 border-t-2 border-black">
        <div className="max-w-6xl mx-auto text-center">
          <p>&copy; 2024 Happiness Game. All rights reserved.</p>
        </div>
      </footer>
    </main>
  )
}