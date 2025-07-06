import SwiftUI

// Type definitions
enum EventType: String, CaseIterable, Codable {
    case findLocation = "場所を探す"
    case takePhoto = "写真を撮る"
    case animeScene = "アニメシーンを探す"
    case animeQuiz = "アニメクイズ"
}

struct SpotEvent: Identifiable, Codable {
    let id = UUID()
    var type: EventType
    var description: String
    var question: String = ""
    var answer: String = ""
}

struct VisitSpot: Identifiable, Codable {
    let id = UUID()
    var name: String
    var address: String = ""
    var notes: String = ""
    var event: SpotEvent?
}

struct VisitPlanData: Identifiable, Codable {
    let id = UUID()
    var animeName: String
    var title: String
    var duration: String
    var spots: [VisitSpot]
    var thumbnailData: Data?
    var createdDate: Date = Date()
}

struct VisitGameScreen: View {
    let animeName: String
    let duration: String
    let spots: [VisitSpot]
    
    @Environment(\.dismiss) var dismiss
    @State private var currentSpotIndex: Int = 0
    @State private var showingEventDetail = false
    @State private var completedSpots: Set<Int> = []
    @State private var userAnswer: String = ""
    @State private var showingResult = false
    @State private var isCorrect = false
    
    var remainingSpots: [VisitSpot] {
        spots.filter { !completedSpots.contains(spots.firstIndex(where: { $0.id == $1.id }) ?? -1) }
    }
    
    var currentSpot: VisitSpot? {
        guard currentSpotIndex < spots.count else { return nil }
        return spots[currentSpotIndex]
    }
    
    var body: some View {
        NavigationView {
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
                                            // このスポットをスキップ
                                            if currentSpotIndex < spots.count - 1 {
                                                currentSpotIndex += 1
                                                userAnswer = ""
                                            }
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
                                            completedSpots.insert(currentSpotIndex)
                                            if currentSpotIndex < spots.count - 1 {
                                                currentSpotIndex += 1
                                                userAnswer = ""
                                            } else if completedSpots.count == spots.count {
                                                // 全て完了
                                                showingResult = true
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
            .navigationBarHidden(true)
        }
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
} 