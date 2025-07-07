import SwiftUI
import Foundation
import UIKit

// VisitTypes.swiftの型を使用するための明示的なimport

struct VisitGameScreen: View {
    let animeName: String
    let duration: String
    let spots: [VisitSpot]
    
    @Environment(\.dismiss) var dismiss
    
    init(animeName: String, duration: String, spots: [VisitSpot]) {
        self.animeName = animeName
        self.duration = duration
        self.spots = spots
        print("DEBUG: VisitGameScreen初期化")
        print("DEBUG: animeName = \(animeName)")
        print("DEBUG: duration = \(duration)")
        print("DEBUG: spots count = \(spots.count)")
    }
    @State private var currentSpotIndex: Int = 0
    @State private var showingEventDetail = false
    @State private var completedSpots: Set<Int> = []
    @State private var userAnswer: String = ""
    @State private var showingResult = false
    @State private var isCorrect = false
    
    // スロット演出用の状態
    @State private var isSlotAnimating = false
    @State private var showSlotMachine = true
    @State private var slotOffset: CGFloat = 0
    @State private var selectedSpotIndex: Int? = nil
    @State private var stamps: [UUID: Bool] = [:]
    
    var remainingSpots: [VisitSpot] {
        spots.enumerated().filter { !completedSpots.contains($0.offset) }.map { $0.element }
    }
    
    var currentSpot: VisitSpot? {
        guard let index = selectedSpotIndex, index < spots.count else { return nil }
        return spots[index]
    }
    
    var body: some View {
        let _ = print("DEBUG: VisitGameScreen.body呼び出し")
        ZStack {
                // 背景
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // ヘッダー
                    HStack {
                        Button(action: { dismiss() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 18, weight: .medium))
                                Text("終了")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .foregroundColor(.red)
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 2) {
                            Text("\(animeName)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                            Text("\(completedSpots.count) / \(spots.count) 完了")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        
                        Spacer()
                        
                        // スペースバランス用の透明ボタン
                        Button(action: {}) {
                            Text("終了")
                                .font(.system(size: 16, weight: .medium))
                                .opacity(0)
                        }
                        .disabled(true)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    
                    // メインコンテンツ
                    if showSlotMachine && remainingSpots.count > 0 {
                        // スロットマシン画面
                        VStack(spacing: 40) {
                            Text("次のスポットを決めよう！")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.purple)
                                .padding(.top, 40)
                            
                            // スロットマシン
                            ZStack {
                                // 背景フレーム
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.yellow.opacity(0.3), Color.orange.opacity(0.3)]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 320, height: 200)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(Color.orange, lineWidth: 4)
                                    )
                                
                                // スロット表示部分
                                VStack {
                                    GeometryReader { geometry in
                                        ScrollView(.vertical, showsIndicators: false) {
                                            VStack(spacing: 0) {
                                                // ダミーを含めたスポットリスト（無限ループ風演出）
                                                ForEach(0..<(remainingSpots.count * 5), id: \.self) { index in
                                                    let spot = remainingSpots[index % remainingSpots.count]
                                                    VStack(spacing: 8) {
                                                        Image(systemName: "mappin.circle.fill")
                                                            .font(.system(size: 40))
                                                            .foregroundColor(.red)
                                                        Text(spot.name)
                                                            .font(.system(size: 20, weight: .bold))
                                                            .multilineTextAlignment(.center)
                                                    }
                                                    .frame(width: 280, height: 120)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 12)
                                                            .fill(Color.white)
                                                            .shadow(radius: 5)
                                                    )
                                                    .padding(.vertical, 10)
                                                }
                                            }
                                            .offset(y: slotOffset)
                                        }
                                        .disabled(true)
                                        .frame(width: geometry.size.width, height: 140)
                                        .clipped()
                                    }
                                    .frame(height: 140)
                                }
                                .frame(width: 300, height: 160)
                                
                                // 選択フレーム
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.red, lineWidth: 4)
                                    .frame(width: 290, height: 140)
                                    .shadow(color: .red.opacity(0.5), radius: 10)
                            }
                            
                            // スタートボタン
                            Button(action: startSlotAnimation) {
                                HStack {
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 30))
                                    Text(isSlotAnimating ? "回転中..." : "スタート！")
                                        .font(.system(size: 24, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 60)
                                .padding(.vertical, 20)
                                .background(
                                    RoundedRectangle(cornerRadius: 30)
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: isSlotAnimating ? [Color.gray, Color.gray.opacity(0.8)] : [Color.red, Color.orange]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                                .scaleEffect(isSlotAnimating ? 0.95 : 1.0)
                                .animation(.easeInOut(duration: 0.2), value: isSlotAnimating)
                            }
                            .disabled(isSlotAnimating)
                            
                            Spacer()
                        }
                    } else {
                        // 通常のゲーム画面
                        ScrollView {
                            VStack(spacing: 24) {
                                // 進捗バー
                                VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("進捗")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Text("\(Int(Double(completedSpots.count) / Double(spots.count) * 100))%")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.blue)
                                }
                                
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(.systemGray5))
                                            .frame(height: 12)
                                        
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [Color.blue, Color.purple]),
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                            .frame(
                                                width: geometry.size.width * (Double(completedSpots.count) / Double(spots.count)),
                                                height: 12
                                            )
                                            .animation(.spring(), value: completedSpots.count)
                                    }
                                }
                                .frame(height: 12)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            
                            // 現在のスポット情報
                            if let spot = currentSpot {
                                VStack(spacing: 20) {
                                    // スポット情報カード
                                    VStack(alignment: .leading, spacing: 16) {
                                        HStack {
                                            Image(systemName: "mappin.circle.fill")
                                                .font(.system(size: 30))
                                                .foregroundColor(.red)
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(spot.name)
                                                    .font(.system(size: 20, weight: .semibold))
                                                if !spot.address.isEmpty {
                                                    Text(spot.address)
                                                        .font(.system(size: 14))
                                                        .foregroundColor(.gray)
                                                }
                                            }
                                            
                                            Spacer()
                                        }
                                        
                                        if !spot.notes.isEmpty {
                                            Text(spot.notes)
                                                .font(.system(size: 14))
                                                .foregroundColor(.gray)
                                                .padding(.top, 4)
                                        }
                                    }
                                    .padding(20)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.white)
                                            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                                    )
                                    .padding(.horizontal, 16)
                                    
                                    // イベント情報
                                    if let event = spot.event {
                                        VStack(spacing: 16) {
                                            HStack {
                                                Image(systemName: iconForEventType(event.type))
                                                    .font(.system(size: 24))
                                                    .foregroundColor(.white)
                                                    .frame(width: 40, height: 40)
                                                    .background(
                                                        Circle()
                                                            .fill(Color.blue)
                                                    )
                                                
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(event.type.rawValue)
                                                        .font(.system(size: 16, weight: .semibold))
                                                    Text(event.description)
                                                        .font(.system(size: 14))
                                                        .foregroundColor(.gray)
                                                }
                                                
                                                Spacer()
                                            }
                                            
                                            if event.type == .animeQuiz && !event.question.isEmpty {
                                                VStack(alignment: .leading, spacing: 12) {
                                                    Text("クイズ")
                                                        .font(.system(size: 14, weight: .semibold))
                                                        .foregroundColor(.blue)
                                                    
                                                    Text(event.question)
                                                        .font(.system(size: 16))
                                                    
                                                    TextField("答えを入力", text: $userAnswer)
                                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                                    
                                                    Button(action: {
                                                        isCorrect = userAnswer.lowercased() == event.answer.lowercased()
                                                        showingResult = true
                                                    }) {
                                                        Text("答えを確認")
                                                            .font(.system(size: 16, weight: .semibold))
                                                            .foregroundColor(.white)
                                                            .frame(maxWidth: .infinity)
                                                            .padding(.vertical, 12)
                                                            .background(
                                                                RoundedRectangle(cornerRadius: 8)
                                                                    .fill(Color.blue)
                                                            )
                                                    }
                                                }
                                                .padding(.top, 8)
                                            }
                                        }
                                        .padding(20)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(Color.blue.opacity(0.05))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 16)
                                                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                                                )
                                        )
                                        .padding(.horizontal, 16)
                                    }
                                    
                                    // アクションボタン
                                    HStack(spacing: 16) {
                                        Button(action: {
                                            // このスポットをスキップしてスロットマシンに戻る
                                            userAnswer = ""
                                            showSlotMachine = true
                                            selectedSpotIndex = nil
                                        }) {
                                            Text("スキップ")
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(.gray)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 16)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(Color.gray, lineWidth: 1)
                                                )
                                        }
                                        
                                        Button(action: {
                                            // このスポットを完了
                                            if let spotIndex = selectedSpotIndex {
                                                completedSpots.insert(spotIndex)
                                                stamps[spots[spotIndex].id] = true
                                            }
                                            userAnswer = ""
                                            
                                            if completedSpots.count == spots.count {
                                                // 全て完了
                                                showingResult = true
                                            } else {
                                                // スロットマシンに戻る
                                                showSlotMachine = true
                                                selectedSpotIndex = nil
                                            }
                                        }) {
                                            Text("完了")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 16)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(Color.green)
                                                )
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                            
                            // 残りのスポット一覧
                            if remainingSpots.count > 1 {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("残りのスポット")
                                        .font(.system(size: 16, weight: .semibold))
                                        .padding(.horizontal, 16)
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 12) {
                                            ForEach(remainingSpots.filter { $0.id != currentSpot?.id }) { spot in
                                                VStack(alignment: .leading, spacing: 8) {
                                                    Image(systemName: "mappin.circle")
                                                        .font(.system(size: 20))
                                                        .foregroundColor(.gray)
                                                    Text(spot.name)
                                                        .font(.system(size: 14, weight: .medium))
                                                        .lineLimit(2)
                                                        .frame(width: 120, alignment: .leading)
                                                }
                                                .padding(12)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(Color(.systemGray6))
                                                )
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                    }
                                }
                                .padding(.top, 20)
                            }
                        }
                        .padding(.bottom, 40)
                    }
                    }
                }
            }
            .navigationBarHidden(true)
        .alert(isPresented: $showingResult) {
            if completedSpots.count == spots.count {
                return Alert(
                    title: Text("おめでとうございます！"),
                    message: Text("全てのスポットを巡りました！"),
                    dismissButton: .default(Text("OK")) {
                        dismiss()
                    }
                )
            } else if let event = currentSpot?.event, event.type == .animeQuiz {
                return Alert(
                    title: Text(isCorrect ? "正解！" : "不正解"),
                    message: Text(isCorrect ? "素晴らしい！" : "正解は: \(event.answer)"),
                    dismissButton: .default(Text("OK"))
                )
            } else {
                return Alert(title: Text(""))
            }
        }
    }
    
    func iconForEventType(_ type: EventType) -> String {
        switch type {
        case .findLocation:
            return "map"
        case .takePhoto:
            return "camera"
        case .animeScene:
            return "tv"
        case .animeQuiz:
            return "questionmark.circle"
        }
    }
    
    func startSlotAnimation() {
        isSlotAnimating = true
        
        // アニメーション開始
        withAnimation(.easeInOut(duration: 0.5)) {
            slotOffset = -CGFloat.random(in: 2000...3000)
        }
        
        // 2秒後に停止
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // ランダムにスポットを選択
            let remainingIndices = spots.enumerated()
                .filter { !completedSpots.contains($0.offset) }
                .map { $0.offset }
            
            if let randomIndex = remainingIndices.randomElement() {
                selectedSpotIndex = randomIndex
                
                // 選択されたスポットの位置に調整
                let spotPosition = CGFloat(remainingIndices.firstIndex(of: randomIndex) ?? 0)
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0)) {
                    slotOffset = -(spotPosition * 140 + spotPosition * 20 + 70)
                }
                
                // アニメーション終了後、ゲーム画面に遷移
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    isSlotAnimating = false
                    showSlotMachine = false
                }
            }
        }
    }
} 
