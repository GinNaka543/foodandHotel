import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'Happiness Game - あなたの推しとの思い出を記録',
  description: '推しキャラ・声優の誕生日リマインダー、聖地巡礼の記録、思い出の保存ができるアプリ',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="ja">
      <body>{children}</body>
    </html>
  )
}