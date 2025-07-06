import SwiftUI

struct VisitSpot: Identifiable, Codable {
    let id = UUID()
    var name: String
    var address: String = ""
    var notes: String = ""
}

struct VisitPlanningScreen: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedDuration: String = ""
    @State private var spots: [VisitSpot] = []
    @State private var showingAddSpotSheet = false
    @State private var animeName: String = ""
    @State private var showingGame = false
    
    let durations = ["半日", "1日", "3日"]
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 0) {
                    // ヘッダー
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 24))
                                .foregroundColor(.black)
                        }
                        Spacer()
                        Text("聖地巡礼プラン")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.black)
                        Spacer()
                        Color.clear
                            .frame(width: 24, height: 24)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                    
                    ScrollView {
                        VStack(spacing: 24) {
                            // アニメ名入力
                            VStack(alignment: .leading, spacing: 8) {
                                Text("アニメ名")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.black)
                                TextField("アニメタイトルを入力", text: $animeName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .font(.system(size: 16))
                            }
                            .padding(.horizontal)
                            
                            // 日数選択
                            VStack(alignment: .leading, spacing: 12) {
                                Text("巡礼日数を選択")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.black)
                                    .padding(.horizontal)
                                
                                HStack(spacing: 12) {
                                    ForEach(durations, id: \.self) { duration in
                                        Button(action: {
                                            selectedDuration = duration
                                        }) {
                                            Text(duration)
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(selectedDuration == duration ? .white : .black)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 12)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(selectedDuration == duration ? Color.blue : Color(.systemGray5))
                                                )
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            // スポット一覧
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("巡礼スポット")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.black)
                                    Spacer()
                                    Button(action: {
                                        showingAddSpotSheet = true
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "plus.circle.fill")
                                            Text("追加")
                                        }
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.blue)
                                    }
                                }
                                .padding(.horizontal)
                                
                                if spots.isEmpty {
                                    Text("スポットを追加してください")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(.vertical, 32)
                                } else {
                                    ForEach(spots) { spot in
                                        SpotRow(spot: spot, onDelete: {
                                            spots.removeAll { $0.id == spot.id }
                                        })
                                    }
                                }
                            }
                        }
                        .padding(.vertical)
                    }
                    
                    // ゲーム開始ボタン
                    Button(action: {
                        if !selectedDuration.isEmpty && !spots.isEmpty {
                            showingGame = true
                        }
                    }) {
                        Text("ゲーム開始")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill((!selectedDuration.isEmpty && !spots.isEmpty) ? Color.blue : Color.gray)
                            )
                    }
                    .disabled(selectedDuration.isEmpty || spots.isEmpty)
                    .padding()
                }
            }
            .sheet(isPresented: $showingAddSpotSheet) {
                AddSpotSheet(spots: $spots)
            }
            .fullScreenCover(isPresented: $showingGame) {
                VisitGameScreen(
                    animeName: animeName,
                    duration: selectedDuration,
                    spots: spots
                )
            }
        }
    }
}

struct SpotRow: View {
    let spot: VisitSpot
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(spot.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.black)
                if !spot.address.isEmpty {
                    Text(spot.address)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
            }
            Spacer()
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 16))
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
        .padding(.horizontal)
    }
}

struct AddSpotSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var spots: [VisitSpot]
    @State private var spotName = ""
    @State private var spotAddress = ""
    @State private var spotNotes = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("スポット名")
                        .font(.system(size: 16, weight: .medium))
                    TextField("例: 藤沢駅", text: $spotName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("住所（任意）")
                        .font(.system(size: 16, weight: .medium))
                    TextField("例: 神奈川県藤沢市", text: $spotAddress)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("メモ（任意）")
                        .font(.system(size: 16, weight: .medium))
                    TextField("例: 第1話で登場", text: $spotNotes)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("スポットを追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("追加") {
                        if !spotName.isEmpty {
                            let newSpot = VisitSpot(
                                name: spotName,
                                address: spotAddress,
                                notes: spotNotes
                            )
                            spots.append(newSpot)
                            dismiss()
                        }
                    }
                    .disabled(spotName.isEmpty)
                }
            }
        }
    }
}

// ゲーム画面（仮実装）
struct VisitGameScreen: View {
    @Environment(\.dismiss) var dismiss
    let animeName: String
    let duration: String
    let spots: [VisitSpot]
    @State private var currentSpotIndex = 0
    @State private var visitedSpots: Set<UUID> = []
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.gray)
                }
                Spacer()
            }
            .padding()
            
            Text("\(animeName.isEmpty ? "聖地巡礼" : animeName)の旅")
                .font(.system(size: 24, weight: .bold))
            
            Text("期間: \(duration)")
                .font(.system(size: 18))
                .foregroundColor(.gray)
            
            Spacer()
            
            if currentSpotIndex < spots.count {
                VStack(spacing: 16) {
                    Text("次の目的地")
                        .font(.system(size: 20, weight: .medium))
                    
                    Text(spots[currentSpotIndex].name)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.blue)
                    
                    if !spots[currentSpotIndex].address.isEmpty {
                        Text(spots[currentSpotIndex].address)
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    }
                    
                    Button(action: {
                        visitedSpots.insert(spots[currentSpotIndex].id)
                        if currentSpotIndex < spots.count - 1 {
                            currentSpotIndex += 1
                        }
                    }) {
                        Text("到着しました！")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.green)
                            )
                    }
                }
            }
            
            Spacer()
            
            // 進捗表示
            HStack {
                Text("訪問済み: \(visitedSpots.count) / \(spots.count)")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
            }
            .padding()
        }
    }
}