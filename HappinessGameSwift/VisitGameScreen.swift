import SwiftUI

// カスタム画像ローダー
class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading = false
    
    func loadImage(from url: URL) {
        print("🔄 [DEBUG] ImageLoader: 画像読み込み開始 - \(url)")
        isLoading = true
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    print("❌ [DEBUG] ImageLoader: エラー - \(error)")
                    return
                }
                
                if let data = data, let loadedImage = UIImage(data: data) {
                    print("✅ [DEBUG] ImageLoader: 画像読み込み成功 - サイズ: \(loadedImage.size)")
                    self.image = loadedImage
                } else {
                    print("❌ [DEBUG] ImageLoader: 画像データの変換に失敗")
                }
            }
        }.resume()
    }
}

// カスタム画像ビュー
struct CustomAsyncImage: View {
    let url: URL
    let width: CGFloat
    let height: CGFloat
    
    @StateObject private var loader = ImageLoader()
    
    var body: some View {
        Group {
            if let image = loader.image {
                let _ = print("🎨 [DEBUG] CustomAsyncImage: 画像表示中")
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipped()
            } else if loader.isLoading {
                let _ = print("⏳ [DEBUG] CustomAsyncImage: 読み込み中")
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.purple) // 読み込み中は紫色
                    .frame(width: width, height: height)
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    )
            } else {
                let _ = print("❌ [DEBUG] CustomAsyncImage: 画像なし")
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray)
                    .frame(width: width, height: height)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                    )
            }
        }
        .onAppear {
            loader.loadImage(from: url)
        }
    }
}

// スポットリストビュー
struct SpotListView: View {
    @Binding var spots: [VisitSpot]
    let selectedDay: Int
    @Binding var selectedSpot: VisitSpot?
    @Binding var showingDetail: Bool
    @Binding var newlyCompletedSpots: Set<UUID>
    @Binding var updateTrigger: Bool
    
    var body: some View {
        let daySpots = spots.filter { $0.dayNumber == selectedDay }
        ForEach(Array(daySpots.enumerated()), id: \.element.id) { index, spot in
            if let originalIndex = spots.firstIndex(where: { $0.id == spot.id }) {
                VStack(spacing: 0) {
                    SpotCard(
                        spot: spot,
                        index: index,
                        isCompleted: spots[originalIndex].isCompleted,
                        isNewlyCompleted: newlyCompletedSpots.contains(spot.id),
                        onTap: {
                            selectedSpot = spots[originalIndex]
                            showingDetail = true
                        },
                        onToggle: {
                            print("🔄 DEBUG: onToggle呼び出し - スポット: \(spot.name)")
                            print("🔄 DEBUG: originalIndex: \(originalIndex)")
                            print("🔄 DEBUG: 更新前isCompleted: \(spots[originalIndex].isCompleted)")
                            
                            // 明示的に値を反転
                            let newValue = !spots[originalIndex].isCompleted
                            spots[originalIndex].isCompleted = newValue
                            
                            // 新しく完了したスポットを追跡
                            if newValue {
                                newlyCompletedSpots.insert(spot.id)
                                // 3秒後に新規完了フラグをクリア
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                    newlyCompletedSpots.remove(spot.id)
                                }
                            } else {
                                newlyCompletedSpots.remove(spot.id)
                            }
                            
                            print("🔄 DEBUG: 設定した値: \(newValue)")
                            print("🔄 DEBUG: 更新後isCompleted: \(spots[originalIndex].isCompleted)")
                            
                            // 強制的にUIを更新
                            updateTrigger.toggle()
                            
                            // 配列全体の状態を確認
                            print("🔄 DEBUG: spots配列の状態:")
                            for (idx, s) in spots.enumerated() {
                                print("  [\(idx)] \(s.name): \(s.isCompleted)")
                            }
                        }
                    )
                    
                    // 交通機関情報
                    if index < daySpots.count - 1, let transport = spot.transportToNext {
                        TransportCard(transport: transport)
                    }
                }
            }
        }
    }
}

// 日付タブビュー
struct DayTabsView: View {
    let numberOfDays: Int
    @Binding var selectedDay: Int
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(1...min(numberOfDays, 30), id: \.self) { day in
                    Button(action: { selectedDay = day }) {
                        Text("Day \(day)")
                            .font(.system(size: 14, weight: selectedDay == day ? .semibold : .medium))
                            .foregroundColor(selectedDay == day ? .white : .black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedDay == day ? Color.blue : Color(.systemGray5))
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

// ヘッダービュー
struct VisitGameHeader: View {
    let planTitle: String
    let filteredSpotsCompletedCount: Int
    let filteredSpotsCount: Int
    let onClose: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onClose) {
                HStack(spacing: 4) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .medium))
                }
                .foregroundColor(.gray)
                .padding(8)
                .background(Circle().fill(Color(.systemGray5)))
            }
            
            Spacer()
            
            Text(planTitle)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.black)
            
            Spacer()
            
            // 進捗表示
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: filteredSpotsCount > 0 ? CGFloat(filteredSpotsCompletedCount) / CGFloat(filteredSpotsCount) : 0)
                    .stroke(Color.purple, lineWidth: 4)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: filteredSpotsCompletedCount)
                Text("\(filteredSpotsCompletedCount)/\(filteredSpotsCount)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.purple)
                    .scaleEffect(filteredSpotsCompletedCount > 0 ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: filteredSpotsCompletedCount)
            }
            .frame(width: 50, height: 50)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
}

struct VisitGameScreen: View {
    @Environment(\.dismiss) var dismiss
    let animeName: String
    let duration: String
    let planTitle: String
    @State var spots: [VisitSpot]
    @State private var currentSpotIndex = 0
    @State private var showingDetail = false
    @State private var selectedSpot: VisitSpot?
    @State private var selectedDay: Int = 1
    @State private var updateTrigger = false  // 強制更新用
    @State private var newlyCompletedSpots: Set<UUID> = [] // 新しく完了したスポットを追跡
    let numberOfDays: Int
    let startTime: Date
    let onClose: (() -> Void)?
    let planId: UUID?
    
    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter
    }()
    
    let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    
    var completedSpotsCount: Int {
        spots.filter { $0.isCompleted }.count
    }
    
    var filteredSpotsCompletedCount: Int {
        spots.filter { $0.dayNumber == selectedDay && $0.isCompleted }.count
    }
    
    var filteredSpotsCount: Int {
        spots.filter { $0.dayNumber == selectedDay }.count
    }
    
    var mainContent: some View {
        VStack(spacing: 0) {
            // 現在時刻と開始時刻の表示
            let filteredSpots = spots.filter { $0.dayNumber == selectedDay }
            if let firstSpot = filteredSpots.first, let startTime = firstSpot.arrivalTime {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.blue)
                    Text("開始時刻: \(timeFormatter.string(from: startTime))")
                        .font(.system(size: 14, weight: .medium))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
            }
            
            // スポットリスト
            SpotListView(
                spots: $spots,
                selectedDay: selectedDay,
                selectedSpot: $selectedSpot,
                showingDetail: $showingDetail,
                newlyCompletedSpots: $newlyCompletedSpots,
                updateTrigger: $updateTrigger
            )
            
            // 完了メッセージ
            if filteredSpotsCount > 0 && filteredSpotsCompletedCount == filteredSpotsCount {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.purple)
                        .scaleEffect(1.1)
                        .animation(.easeInOut(duration: 0.3).repeatCount(1), value: filteredSpotsCompletedCount)
                    Text("Day \(selectedDay)のスポットを\nすべて巡りました！")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.purple)
                        .multilineTextAlignment(.center)
                    if completedSpotsCount == spots.count {
                        Text("すべての日程が完了しました\nお疲れ様でした")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.vertical, 40)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.purple.opacity(0.1))
                )
                .padding(.horizontal, 16)
            }
        }
        .padding(.bottom, 100)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ヘッダー
                VisitGameHeader(
                    planTitle: planTitle,
                    filteredSpotsCompletedCount: filteredSpotsCompletedCount,
                    filteredSpotsCount: filteredSpotsCount,
                    onClose: {
                        if let onClose = onClose {
                            onClose()
                        } else {
                            dismiss()
                        }
                    }
                )
                
                // 日数が2日以上の場合はタブ表示
                if numberOfDays > 1 {
                    DayTabsView(numberOfDays: numberOfDays, selectedDay: $selectedDay)
                }
                
                ScrollView {
                    mainContent
                }
                .background(Color(.systemGray6))
                
                // 下部のボタン
                if completedSpotsCount == spots.count {
                    Button(action: {
                        if let onClose = onClose {
                            onClose()
                        } else {
                            dismiss()
                        }
                    }) {
                        Text("完了")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.green)
                            )
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                    .background(Color(.systemBackground))
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(item: $selectedSpot) { spot in
            if let index = spots.firstIndex(where: { $0.id == spot.id }) {
                SpotDetailView(
                    spot: $spots[index], 
                    spots: $spots, 
                    startTime: startTime,
                    savePlanProgress: savePlanProgress
                )
            }
        }
        .onAppear {
            print("🎮 [DEBUG] VisitGameScreen.body 呼び出し")
            print("🎮 [DEBUG] planTitle: \(planTitle)")
            print("🎮 [DEBUG] animeName: \(animeName)")
            print("🎮 [DEBUG] spots.count: \(spots.count)")
            print("🎮 [DEBUG] numberOfDays: \(numberOfDays)")
            print("🎮 [DEBUG] spots dayNumber distribution:")
            for spot in spots {
                print("  - \(spot.name): day \(spot.dayNumber)")
            }
            if spots.isEmpty {
                print("⚠️ WARNING: spotsが空です！")
            }
        }
        .background(Color(.systemBackground))
    }
    
    func toggleSpotCompletion(spotId: UUID) {
        print("DEBUG: toggleSpotCompletion が呼び出されました - ID: \(spotId)")
        
        if let index = spots.firstIndex(where: { $0.id == spotId }) {
            let oldValue = spots[index].isCompleted
            
            print("DEBUG: toggle前の詳細情報")
            print("  - スポット名: \(spots[index].name)")
            print("  - 現在のisCompleted: \(spots[index].isCompleted)")
            print("  - スポットID: \(spots[index].id)")
            
            // 明示的にwithAnimationを使って更新
            withAnimation(.easeInOut(duration: 0.2)) {
                spots[index].isCompleted = !spots[index].isCompleted
            }
            
            let newValue = spots[index].isCompleted
            print("  - 配列更新後のisCompleted: \(newValue)")
            
            print("DEBUG: スポット完了状態変更")
            print("  - スポット名: \(spots[index].name)")
            print("  - 変更前: \(oldValue)")
            print("  - 変更後: \(newValue)")
            
            // UI更新を強制する
            DispatchQueue.main.async {
                self.savePlanProgress()
            }
        } else {
            print("ERROR: スポットが見つかりません - ID: \(spotId)")
            print("DEBUG: 利用可能なスポットID一覧:")
            for spot in spots {
                print("  - \(spot.name): \(spot.id)")
            }
        }
    }
    
    func savePlanProgress() {
        do {
            let encoder = JSONEncoder()
            
            // UserDefaultsから現在の保存されたプランを読み込み
            if let savedPlansData = UserDefaults.standard.data(forKey: "savedPlans"),
               var savedPlans = try? JSONDecoder().decode([VisitPlanData].self, from: savedPlansData) {
                
                print("DEBUG: 保存されたプラン数: \(savedPlans.count)")
                
                // 現在のプランを見つけて更新
                var planFound = false
                
                // 1. まずIDで検索
                if let planId = planId {
                    for i in 0..<savedPlans.count {
                        if savedPlans[i].id == planId {
                            print("DEBUG: IDで一致するプランが見つかりました")
                            savedPlans[i].spots = spots
                            savedPlans[i].lastVisitedDate = Date()
                            planFound = true
                            break
                        }
                    }
                }
                
                // 2. IDで見つからない場合は、タイトルとアニメ名で検索
                if !planFound {
                    for i in 0..<savedPlans.count {
                        print("DEBUG: プラン \(i): title='\(savedPlans[i].title)', animeName='\(savedPlans[i].animeName)'")
                        if savedPlans[i].title == planTitle && savedPlans[i].animeName == animeName {
                            print("DEBUG: タイトルとアニメ名で一致するプランが見つかりました")
                            savedPlans[i].spots = spots
                            savedPlans[i].lastVisitedDate = Date()
                            planFound = true
                            break
                        }
                    }
                }
                
                // 3. それでも見つからない場合は、アニメ名のみで検索して類似プランを探す
                if !planFound {
                    for i in 0..<savedPlans.count {
                        if savedPlans[i].animeName == animeName {
                            print("DEBUG: アニメ名のみで一致するプランが見つかりました (プラン: \(savedPlans[i].title))")
                            savedPlans[i].spots = spots
                            savedPlans[i].lastVisitedDate = Date()
                            planFound = true
                            break
                        }
                    }
                }
                
                if !planFound {
                    print("ERROR: 一致するプランが見つかりません")
                    print("  検索対象: planId=\(planId?.uuidString ?? "nil"), planTitle='\(planTitle)', animeName='\(animeName)'")
                } else {
                    print("DEBUG: プランの進捗が保存されました")
                }
                
                // 更新されたプランをUserDefaultsに保存
                let updatedData = try encoder.encode(savedPlans)
                UserDefaults.standard.set(updatedData, forKey: "savedPlans")
                
            } else {
                print("ERROR: 保存されたプランデータが見つかりません")
            }
        } catch {
            print("ERROR: プランの進捗保存に失敗しました: \(error)")
        }
    }
}

struct SpotCard: View {
    let spot: VisitSpot
    let index: Int
    let isCompleted: Bool
    let isNewlyCompleted: Bool
    let onTap: () -> Void
    let onToggle: () -> Void
    
    let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    
    var body: some View {
        HStack(spacing: 12) {
            // スポット画像（タップで詳細表示）
            ZStack(alignment: .topLeading) {
                Button(action: onTap) {
                    let _ = print("🔍 [DEBUG] Button内部に入った - スポット: \(spot.name)")
                    let _ = print("🔍 [DEBUG] 画像表示条件チェック - スポット: \(spot.name)")
                let _ = print("🔍 [DEBUG] imageData: \(spot.imageData != nil ? "あり" : "なし")")
                let _ = print("🔍 [DEBUG] imageUrl: '\(spot.imageUrl)'")
                let _ = print("🔍 [DEBUG] images: \(spot.images)")
                
                if let imageData = spot.imageData, let uiImage = UIImage(data: imageData) {
                        let _ = print("✅ [DEBUG] ローカル画像を表示")
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 140, height: 100)
                            .clipped()
                            .cornerRadius(8)
                    } else if !spot.imageUrl.isEmpty || !spot.images.isEmpty {
                        let _ = print("✅ [DEBUG] Web画像表示条件に入った")
                        // Web管理画面から作成されたプランの画像を表示
                        let imageUrlToUse = !spot.imageUrl.isEmpty ? spot.imageUrl : (spot.images.first ?? "")
                        let _ = print("🖼️ [DEBUG] スポット \(spot.name) の画像URL: '\(imageUrlToUse)'")
                        let _ = print("🔗 [DEBUG] URL作成結果: \(URL(string: imageUrlToUse)?.absoluteString ?? "nil")")
                        
                        // URLに問題がないか最終チェック
                        if let url = URL(string: imageUrlToUse), !imageUrlToUse.isEmpty {
                            CustomAsyncImage(url: url, width: 140, height: 100)
                                .cornerRadius(8)
                        } else {
                            let _ = print("❌ [DEBUG] 無効なURL: '\(imageUrlToUse)'")
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.orange) // デバッグ用にオレンジ色に変更
                                .frame(width: 140, height: 100)
                                .overlay(
                                    Image(systemName: "exclamationmark.triangle")
                                        .font(.system(size: 30))
                                        .foregroundColor(.white)
                                )
                        }
                    } else {
                        let _ = print("❌ [DEBUG] 画像なし - デフォルト画像を表示")
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue) // デバッグ用に青色に変更
                            .frame(width: 140, height: 100)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.system(size: 30))
                                    .foregroundColor(.white)
                            )
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .background(Color.green.opacity(0.3)) // デバッグ用背景色
                
                // 滞在時間バッジ（左上に配置）
                Text("\(spot.stayDuration)分")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.orange)
                    )
                    .padding(.top, 8)
                    .padding(.leading, 8)
            }
                
            VStack(alignment: .leading, spacing: 6) {
                // スポット名
                Text(spot.name)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                    .lineLimit(2)
                    .padding(.top, 15) // 15ピクセル下げる
                    
                    // 滞在時間帯
                    if !spot.timeRange.isEmpty {
                        Text(spot.timeRange)
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                    }
                    
                    // 住所情報
                    if !spot.address.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                            Text(spot.address)
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                }
                
                Spacer()
                
                // チェックボックス
                Button(action: {
                    print("🔘 DEBUG: チェックボックスが押されました - スポット: \(spot.name)")
                    print("🔘 DEBUG: 現在のisCompleted: \(isCompleted)")
                    print("🔘 DEBUG: spot.id: \(spot.id)")
                    
                    // ハプティックフィードバック
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    
                    onToggle()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 28))
                            .foregroundColor(isCompleted ? .purple : .gray)
                            .scaleEffect(isCompleted ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: isCompleted)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .contentShape(Circle())
                .padding(.trailing, 8)
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isCompleted ? Color.purple.opacity(0.3) : Color.clear, lineWidth: 2)
        )
        .scaleEffect(isCompleted ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isCompleted)
        .overlay(
            // 新規完了時の祝福エフェクト
            Group {
                if isNewlyCompleted {
                    ZStack {
                        Circle()
                            .fill(Color.purple.opacity(0.2))
                            .scaleEffect(1.5)
                            .opacity(0)
                            .animation(.easeOut(duration: 1.0), value: isNewlyCompleted)
                        
                        Image(systemName: "sparkles")
                            .font(.system(size: 20))
                            .foregroundColor(.purple)
                            .opacity(isNewlyCompleted ? 1 : 0)
                            .animation(.easeInOut(duration: 0.5), value: isNewlyCompleted)
                    }
                }
            }
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}

struct TransportCard: View {
    let transport: TransportInfo
    
    var body: some View {
        HStack(spacing: 12) {
            // 縦線
            Rectangle()
                .fill(Color.orange.opacity(0.3))
                .frame(width: 2, height: 40)
                .padding(.leading, 32)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: transportIcon(transport.method))
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                    Text(transport.method)
                        .font(.system(size: 14, weight: .medium))
                    Text("・ \(transport.duration)分")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    if transport.cost > 0 {
                        Text("・ ¥\(transport.cost)")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                }
                
                if !transport.route.isEmpty {
                    Text(transport.route)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
    }
    
    func transportIcon(_ method: String) -> String {
        switch method {
        case "電車":
            return "tram"
        case "バス":
            return "bus"
        case "徒歩":
            return "figure.walk"
        case "タクシー":
            return "car"
        default:
            return "arrow.right"
        }
    }
}

struct SpotDetailView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var spot: VisitSpot
    @Binding var spots: [VisitSpot]
    let startTime: Date
    let savePlanProgress: () -> Void
    @State private var selectedImageData: Data? = nil
    @State private var showingFullScreenImage = false
    @State private var showingEditSheet = false
    @State private var selectedImageUrl: String? = nil
    @State private var showingFullScreenWebImage = false
    
    let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // サムネイル画像
                    if let imageData = spot.imageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .clipped()
                            .cornerRadius(12)
                    } else if !spot.imageUrl.isEmpty || !spot.images.isEmpty {
                        // Web管理画面から作成されたプランの画像を表示
                        let imageUrlToUse = !spot.imageUrl.isEmpty ? spot.imageUrl : (spot.images.first ?? "")
                        let _ = print("🖼️ [DEBUG] 詳細スポット \(spot.name) の画像URL: '\(imageUrlToUse)'")
                        let _ = print("🔗 [DEBUG] 詳細URL作成結果: \(URL(string: imageUrlToUse)?.absoluteString ?? "nil")")
                        
                        // URLに問題がないか最終チェック
                        if let url = URL(string: imageUrlToUse), !imageUrlToUse.isEmpty {
                            GeometryReader { geometry in
                                CustomAsyncImage(url: url, width: geometry.size.width, height: 200)
                                    .cornerRadius(12)
                            }
                            .frame(height: 200)
                        } else {
                            let _ = print("❌ [DEBUG] 詳細無効なURL: '\(imageUrlToUse)'")
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray5))
                                .frame(maxWidth: .infinity)
                                .frame(height: 200)
                                .overlay(
                                    Image(systemName: "exclamationmark.triangle")
                                        .font(.system(size: 40))
                                        .foregroundColor(.gray)
                                )
                        }
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray5))
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.system(size: 40))
                                    .foregroundColor(.gray)
                            )
                    }
                    
                    // スポット名
                    VStack(alignment: .leading, spacing: 8) {
                        Text("スポット名")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        Text(spot.name)
                            .font(.system(size: 20, weight: .semibold))
                    }
                    
                    // 滞在時間帯
                    if !spot.timeRange.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("滞在時間帯")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                            Text(spot.timeRange)
                                .font(.system(size: 16))
                        }
                    }
                    
                    // ここで何をするのか
                    if !spot.activity.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ここで何をするのか")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                            Text(spot.activity)
                                .font(.system(size: 16))
                        }
                    }
                    
                    // 滞在時間
                    VStack(alignment: .leading, spacing: 8) {
                        Text("滞在時間")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        Label("\(spot.stayDuration)分", systemImage: "clock")
                            .font(.system(size: 16))
                            .foregroundColor(.orange)
                    }
                    
                    // 住所
                    if !spot.address.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("住所")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                            Label(spot.address, systemImage: "mappin")
                                .font(.system(size: 16))
                        }
                    }
                    
                    // メモ
                    if !spot.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("メモ")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                            Text(spot.notes)
                                .font(.system(size: 16))
                        }
                    }
                    
                    // スポット費用
                    if spot.spotCost > 0 {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("費用")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                            Label("¥\(spot.spotCost)", systemImage: "yensign.circle")
                                .font(.system(size: 16))
                                .foregroundColor(.blue)
                        }
                    }
                    
                    // 詳細画像（予約情報など）
                    let hasLocalImages = spot.detailImagesData != nil && !spot.detailImagesData!.isEmpty
                    let hasWebImages = !spot.images.isEmpty
                    
                    if hasLocalImages || hasWebImages {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("詳細画像")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    // ローカル画像を表示
                                    if let detailImagesData = spot.detailImagesData {
                                        ForEach(Array(detailImagesData.enumerated()), id: \.offset) { index, imageData in
                                            if let uiImage = UIImage(data: imageData) {
                                                Image(uiImage: uiImage)
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(height: 150)
                                                    .cornerRadius(8)
                                                    .onTapGesture {
                                                        selectedImageData = imageData
                                                        showingFullScreenImage = true
                                                    }
                                            }
                                        }
                                    }
                                    
                                    // Web管理画面からの画像を表示
                                    ForEach(Array(spot.images.enumerated()), id: \.offset) { index, imageUrl in
                                        if let url = URL(string: imageUrl) {
                                            let _ = print("🖼️ [DEBUG] 詳細画像表示: \(imageUrl)")
                                            CustomAsyncImage(url: url, width: 200, height: 150)
                                                .cornerRadius(8)
                                                .onTapGesture {
                                                    // Web画像のフルスクリーン表示用
                                                    selectedImageUrl = imageUrl
                                                    showingFullScreenWebImage = true
                                                }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // 地図を開くボタン
                    if !spot.address.isEmpty {
                        Button(action: {
                            openInMaps(address: spot.address)
                        }) {
                            Label("地図で開く", systemImage: "map")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("編集") {
                    showingEditSheet = true
                }
                .foregroundColor(.blue)
            }
            ToolbarItem(placement: .principal) {
                Text(spot.name)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("戻る") {
                    dismiss()
                }
                .foregroundColor(.blue)
            }
        }
        .fullScreenCover(isPresented: $showingFullScreenImage) {
            if let imageData = selectedImageData, let uiImage = UIImage(data: imageData) {
                FullScreenImageView(image: uiImage, isPresented: $showingFullScreenImage)
            }
        }
        .fullScreenCover(isPresented: $showingFullScreenWebImage) {
            if let imageUrl = selectedImageUrl, let url = URL(string: imageUrl) {
                FullScreenWebImageView(url: url, isPresented: $showingFullScreenWebImage)
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            if let spotIndex = spots.firstIndex(where: { $0.id == spot.id }) {
                SpotEditView(
                    spot: $spots[spotIndex],
                    onSave: {
                        // 保存処理
                        savePlanProgress()
                        showingEditSheet = false
                    },
                    onCancel: {
                        showingEditSheet = false
                    }
                )
            }
        }
        }
    }
    
    func openInMaps(address: String) {
        let encodedAddress = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "maps://?q=\(encodedAddress)") {
            UIApplication.shared.open(url)
        }
    }
}

struct FullScreenWebImageView: View {
    let url: URL
    @Binding var isPresented: Bool
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @StateObject private var loader = ImageLoader()
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                if let image = loader.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastScale
                                    lastScale = value
                                    scale = scale * delta
                                }
                                .onEnded { value in
                                    lastScale = 1.0
                                    if scale < 1.0 {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            scale = 1.0
                                        }
                                    }
                                }
                                .simultaneously(with:
                                    DragGesture()
                                        .onChanged { value in
                                            offset = CGSize(
                                                width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height
                                            )
                                        }
                                        .onEnded { value in
                                            lastOffset = offset
                                        }
                                )
                        )
                } else if loader.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(2.0)
                } else {
                    Text("画像を読み込めませんでした")
                        .foregroundColor(.white)
                }
            }
            .navigationTitle("画像")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        isPresented = false
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            loader.loadImage(from: url)
        }
    }
}

struct FullScreenImageView: View {
    let image: UIImage
    @Binding var isPresented: Bool
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            let delta = value / lastScale
                            lastScale = value
                            scale = min(max(scale * delta, 1), 4)
                        }
                        .onEnded { _ in
                            lastScale = 1.0
                            if scale < 1 {
                                withAnimation {
                                    scale = 1
                                    offset = .zero
                                }
                            }
                        }
                )
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            offset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            lastOffset = offset
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation {
                        if scale > 1 {
                            scale = 1
                            offset = .zero
                            lastOffset = .zero
                        } else {
                            scale = 2
                        }
                    }
                }
            
            VStack {
                HStack {
                    Spacer()
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding()
                }
                Spacer()
            }
        }
    }
}