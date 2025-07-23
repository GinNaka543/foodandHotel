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
    
    var body: some View {
        ForEach(spots.indices, id: \.self) { index in
            if spots[index].dayNumber == selectedDay {
                VStack(spacing: 0) {
                    SpotCard(
                        spot: spots[index],
                        index: index,
                        isCompleted: spots[index].isCompleted,
                        isNewlyCompleted: newlyCompletedSpots.contains(spots[index].id),
                        onTap: {
                            selectedSpot = spots[index]
                            showingDetail = true
                        },
                        onToggle: {
                            print("🔄 DEBUG: チェックボックスがタップされました")
                            print("  - インデックス: \(index)")
                            print("  - スポット名: \(spots[index].name)")
                            print("  - 現在のisCompleted: \(spots[index].isCompleted)")
                            
                            // 直接ここで値を更新
                            spots[index].isCompleted.toggle()
                            
                            print("  - 更新後のisCompleted: \(spots[index].isCompleted)")
                            
                            // 新しく完了したスポットを追跡
                            if spots[index].isCompleted {
                                newlyCompletedSpots.insert(spots[index].id)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                    newlyCompletedSpots.remove(spots[index].id)
                                }
                            } else {
                                newlyCompletedSpots.remove(spots[index].id)
                            }
                        }
                    )
                    
                    // 交通機関情報
                    let daySpotsSorted = spots.filter { $0.dayNumber == selectedDay }
                    if let currentDayIndex = daySpotsSorted.firstIndex(where: { $0.id == spots[index].id }),
                       currentDayIndex < daySpotsSorted.count - 1,
                       let transport = spots[index].transportToNext {
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

// スポットデータを管理するクラス
class SpotsViewModel: ObservableObject {
    @Published var spots: [VisitSpot]
    
    init(spots: [VisitSpot]) {
        self.spots = spots
    }
}

struct VisitGameScreen: View {
    @Environment(\.dismiss) var dismiss
    let animeName: String
    let duration: String
    let planTitle: String
    @StateObject private var viewModel: SpotsViewModel
    @State private var currentSpotIndex = 0
    @State private var selectedDay: Int = 1
    @State private var newlyCompletedSpots: Set<UUID> = [] // 新しく完了したスポットを追跡
    @State private var showCompleteAnimation = false
    @State private var showCompletionPopup = false
    @State private var showSpotEditSheet = false
    @State private var selectedSpotForEdit: VisitSpot?
    @State private var showStreamingSheet = false
    @State private var showAddSpotSheet = false
    @State private var showAddTransportSheet = false
    @State private var selectedSpotForTransport: VisitSpot?
    let numberOfDays: Int
    let startTime: Date
    let onClose: (() -> Void)?
    let planId: UUID?
    let isReadOnly: Bool
    let streamingUrls: [StreamingService]
    let thumbnailUrl: String?
    
    init(animeName: String, duration: String, planTitle: String, spots: [VisitSpot], numberOfDays: Int, startTime: Date, onClose: (() -> Void)? = nil, planId: UUID? = nil, isReadOnly: Bool = false, streamingUrls: [StreamingService] = [], thumbnailUrl: String? = nil) {
        self.animeName = animeName
        self.duration = duration
        self.planTitle = planTitle
        self._viewModel = StateObject(wrappedValue: SpotsViewModel(spots: spots))
        self.numberOfDays = numberOfDays
        self.startTime = startTime
        self.onClose = onClose
        self.planId = planId
        self.isReadOnly = isReadOnly
        self.streamingUrls = streamingUrls
        self.thumbnailUrl = thumbnailUrl
    }
    
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
        viewModel.spots.filter { $0.isCompleted }.count
    }
    
    var filteredSpotsCompletedCount: Int {
        viewModel.spots.filter { $0.dayNumber == selectedDay && $0.isCompleted }.count
    }
    
    var filteredSpotsCount: Int {
        viewModel.spots.filter { $0.dayNumber == selectedDay }.count
    }
    
    var allSpotsCompleted: Bool {
        !viewModel.spots.isEmpty && viewModel.spots.allSatisfy { $0.isCompleted }
    }
    
    var mainContent: some View {
        VStack(spacing: 0) {
            // 現在時刻と開始時刻の表示
            let filteredSpots = viewModel.spots.filter { $0.dayNumber == selectedDay }
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
            
            // スポットリスト（現在は使用されていません - 新しいbody実装を使用）
            
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
                    if completedSpotsCount == viewModel.spots.count {
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
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    // ヘッダーのスペースを確保
                    Color.clear
                        .frame(height: 60)
                    
                    // メインバナー
                    mainBanner
                    
                    // タブバー
                    animeStyleTabs
                    
                    // メインコンテンツ
                    ScrollView {
                    ZStack(alignment: .leading) {
                        // 背景の縦線（プログレスバーの背景）
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 3)
                            .padding(.leading, 35.5)
                            .padding(.top, 46)
                            .padding(.bottom, 40)
                        
                        LazyVStack(spacing: 0) {
                            let dayFilteredSpots = viewModel.spots.filter { $0.dayNumber == selectedDay }
                            ForEach(Array(dayFilteredSpots.enumerated()), id: \.element.id) { index, spot in
                                if let realIndex = viewModel.spots.firstIndex(where: { $0.id == spot.id }) {
                                    NavigationLink(destination: SpotDetailPageView(
                                        spot: $viewModel.spots[realIndex],
                                        spots: $viewModel.spots,
                                        startTime: startTime,
                                        savePlanProgress: {}
                                    )) {
                                        AnimeStyleSpotCard(
                                            spot: viewModel.spots[realIndex],
                                            isCompleted: viewModel.spots[realIndex].isCompleted,
                                            onToggle: {
                                                // 読み取り専用モードではチェックボックスを無効化
                                                if !isReadOnly {
                                                    withAnimation(.spring()) {
                                                        viewModel.spots[realIndex].isCompleted.toggle()
                                                        if viewModel.spots[realIndex].isCompleted {
                                                            newlyCompletedSpots.insert(viewModel.spots[realIndex].id)
                                                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                                                newlyCompletedSpots.remove(viewModel.spots[realIndex].id)
                                                            }
                                                        }
                                                        
                                                        // 全てのスポットが完了したかチェック
                                                        if allSpotsCompleted {
                                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                                                showCompletionPopup = true
                                                            }
                                                        }
                                                    }
                                                }
                                            },
                                            onTap: {
                                                // NavigationLinkを使用するため、このonTapは使用しない
                                            },
                                            isReadOnly: isReadOnly,
                                            isFirstSpot: index == 0,
                                            isLastSpot: index == dayFilteredSpots.count - 1,
                                            previousDepartureTime: index > 0 ? dayFilteredSpots[index - 1].departureTime : nil,
                                            onEditTransport: {
                                                selectedSpotForTransport = viewModel.spots[realIndex]
                                                showAddTransportSheet = true
                                            }
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 100)
                    }
                }
                .background(Color.white)
                
                // 下部のアクションボタン
                if completedSpotsCount < viewModel.spots.count {
                    bottomActionButton
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                        .background(Color(.systemBackground))
                }
            }
            .background(Color(.systemBackground))
            
            // ヘッダーを最前面に配置
            VStack {
                animeStyleHeader
                    .background(Color(.systemBackground))
                    .zIndex(1000)
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showSpotEditSheet) {
            if let selectedSpot = selectedSpotForEdit,
               let spotIndex = viewModel.spots.firstIndex(where: { $0.id == selectedSpot.id }) {
                SpotEditView(
                    spot: $viewModel.spots[spotIndex],
                    onSave: {
                        showSpotEditSheet = false
                        selectedSpotForEdit = nil
                        // プラン進捗を保存
                        savePlanProgress()
                    },
                    onCancel: {
                        showSpotEditSheet = false
                        selectedSpotForEdit = nil
                    }
                )
            }
        }
        .sheet(isPresented: $showStreamingSheet) {
            StreamingServicesSheet(
                animeName: animeName,
                streamingServices: streamingUrls,
                isPresented: $showStreamingSheet,
                thumbnailUrl: thumbnailUrl
            )
        }
        .sheet(isPresented: $showAddSpotSheet) {
            GameAddSpotView(
                animeName: animeName,
                selectedDay: selectedDay,
                onSave: { newSpot in
                    var spot = newSpot
                    spot.dayNumber = selectedDay
                    
                    // 時刻を設定
                    let daySpots = viewModel.spots.filter { $0.dayNumber == selectedDay }
                    if let lastSpot = daySpots.last {
                        // 最後のスポットの出発時刻から30分後を到着時刻に設定
                        if let lastDeparture = lastSpot.departureTime {
                            spot.arrivalTime = Calendar.current.date(byAdding: .minute, value: 30, to: lastDeparture)
                            spot.departureTime = Calendar.current.date(byAdding: .minute, value: spot.stayDuration, to: spot.arrivalTime!)
                        }
                    } else {
                        // その日の最初のスポットの場合
                        spot.arrivalTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: startTime)
                        spot.departureTime = Calendar.current.date(byAdding: .minute, value: spot.stayDuration, to: spot.arrivalTime!)
                    }
                    
                    viewModel.spots.append(spot)
                    savePlanProgress()
                }
            )
        }
        .sheet(isPresented: $showAddTransportSheet) {
            if let spot = selectedSpotForTransport,
               let spotIndex = viewModel.spots.firstIndex(where: { $0.id == spot.id }) {
                GameAddTransportView(
                    transport: viewModel.spots[spotIndex].transportToNext,
                    onSave: { newTransport in
                        viewModel.spots[spotIndex].transportToNext = newTransport
                        savePlanProgress()
                    }
                )
            }
        }
        }
        .onAppear {
            print("🎮 [DEBUG] VisitGameScreen.body 呼び出し")
            print("🎮 [DEBUG] planTitle: \(planTitle)")
            print("🎮 [DEBUG] animeName: \(animeName)")
            print("🎮 [DEBUG] spots.count: \(viewModel.spots.count)")
            print("🎮 [DEBUG] numberOfDays: \(numberOfDays)")
            print("🎮 [DEBUG] streamingUrls.count: \(streamingUrls.count)")
            print("🎮 [DEBUG] streamingUrls: \(streamingUrls.map { $0.name + ": " + $0.url })")
            print("🎮 [DEBUG] streamingUrls.isEmpty: \(streamingUrls.isEmpty)")
            print("🎮 [DEBUG] spots dayNumber distribution:")
            for spot in viewModel.spots {
                print("  - \(spot.name): day \(spot.dayNumber)")
                if let arrival = spot.arrivalTime, let departure = spot.departureTime {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "HH:mm"
                    print("    到着: \(formatter.string(from: arrival)), 出発: \(formatter.string(from: departure))")
                }
                if let transport = spot.transportToNext {
                    print("    次への移動: \(transport.method) \(transport.duration)分")
                }
            }
            if viewModel.spots.isEmpty {
                print("⚠️ WARNING: spotsが空です！")
            }
            
            // 保存されたプランデータを読み込み
            loadSavedPlanData()
            
            // 訪問進捗を復元
            loadVisitProgress()
        }
        .background(Color(.systemBackground))
        .overlay {
            if showCompletionPopup {
                ImprovedCompletionView(
                    isPresented: $showCompletionPopup,
                    planTitle: planTitle,
                    animeName: animeName,
                    thumbnail: getThumbnailImage()
                )
            }
        }
    }
    
    // アニメページスタイルのヘッダー
    var animeStyleHeader: some View {
        ZStack {
            // スポットカウントを真の中央に配置
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.black)
                Text("\(completedSpotsCount)/\(viewModel.spots.count)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
            
            // 左右のボタンをHStackで配置
            HStack {
                // 戻るボタン
                Button(action: {
                    print("×ボタンがタップされました")
                    if let onClose = onClose {
                        print("onCloseを実行します")
                        onClose()
                    } else {
                        print("dismissを実行します")
                        dismiss()
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.black)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .zIndex(999)
                
                Spacer()
                
                // 右側のボタン群
                HStack(spacing: 8) {
                    // スポット追加ボタン（読み取り専用でない場合のみ表示）
                    if !isReadOnly {
                        Button(action: {
                            showAddSpotSheet = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.purple)
                        }
                    }
                    
                    // Watchボタン
                    Button(action: {
                        showStreamingSheet = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 14))
                            Text("Watch")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(LinearGradient(
                                    gradient: Gradient(colors: [Color.purple, Color.yellow]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    // メインバナー
    var mainBanner: some View {
        VStack(spacing: 0) {
            // バナー画像
            ZStack {
                // 背景画像
                if let firstSpot = viewModel.spots.first,
                   let imageData = firstSpot.imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 200)
                        .clipped()
                } else if let firstSpot = viewModel.spots.first,
                          !firstSpot.imageUrl.isEmpty, let url = URL(string: firstSpot.imageUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.4, green: 0.7, blue: 1.0),
                                    Color(red: 0.2, green: 0.6, blue: 1.0)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                    }
                    .frame(height: 200)
                    .clipped()
                } else {
                    Rectangle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.4, green: 0.7, blue: 1.0),
                                Color(red: 0.2, green: 0.6, blue: 1.0)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(height: 200)
                }
                
                // オーバーレイ
                Rectangle()
                    .fill(Color.black.opacity(0.3))
                    .frame(height: 200)
                
                // テキスト情報
                VStack(spacing: 8) {
                    Text(planTitle)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .shadow(color: Color.black.opacity(0.5), radius: 2, x: 0, y: 1)
                    
                    Text(animeName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .shadow(color: Color.black.opacity(0.5), radius: 2, x: 0, y: 1)
                    
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 14))
                            Text("\(numberOfDays)日間")
                                .font(.system(size: 14))
                        }
                        .foregroundColor(.white.opacity(0.9))
                        
                        HStack(spacing: 4) {
                            Image(systemName: "location")
                                .font(.system(size: 14))
                            Text("\(viewModel.spots.count)スポット")
                                .font(.system(size: 14))
                        }
                        .foregroundColor(.white.opacity(0.9))
                    }
                }
            }
        }
        .background(Color(.systemBackground))
    }
    
    // アニメページスタイルのタブ
    var animeStyleTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(1...numberOfDays, id: \.self) { day in
                    Button(action: {
                        withAnimation(.spring()) {
                            selectedDay = day
                        }
                    }) {
                        Text("Day \(day)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(selectedDay == day ? .white : .black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedDay == day ? Color.black : Color(.systemGray6))
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16) // バナーとの間隔を追加
            .padding(.bottom, 8)
        }
        .background(Color(.systemBackground))
    }
    
    // 元のモダンなヘッダー（予備）
    var modernHeader: some View {
        ZStack {
            // 青いグラデーション背景
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.4, green: 0.7, blue: 1.0),
                    Color(red: 0.2, green: 0.6, blue: 1.0),
                    Color(red: 0.3, green: 0.65, blue: 0.95)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 280) // タブ用のスペースを考慮して調整
            
            VStack(spacing: 16) {
                HStack {
                    Button(action: {
                        if let onClose = onClose {
                            onClose()
                        } else {
                            dismiss()
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    // 進捗表示
                    HStack(spacing: 4) {
                        Image(systemName: "trophy.fill")
                            .foregroundColor(.yellow)
                        Text("\(filteredSpotsCompletedCount)/\(filteredSpotsCount)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 60) // ステータスバーを考慮して余白を増やす
                
                // プランのサムネイル
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white,
                                Color(red: 0.95, green: 0.97, blue: 1.0)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 104, height: 104) // 80 * 1.3 = 104
                    
                    if let thumbnailUrl = thumbnailUrl,
                       !thumbnailUrl.isEmpty,
                       let url = URL(string: thumbnailUrl) {
                        // プランのサムネイルを表示
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 91, height: 91) // 70 * 1.3 = 91
                                .clipShape(Circle())
                        } placeholder: {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                .frame(width: 91, height: 91)
                        }
                    } else if let firstSpot = viewModel.spots.first(where: { $0.dayNumber == selectedDay }),
                              (firstSpot.imageData != nil || !firstSpot.imageUrl.isEmpty) {
                        // フォールバック: スポットの画像を表示
                        if let imageData = firstSpot.imageData, let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 91, height: 91) // 70 * 1.3 = 91
                                .clipShape(Circle())
                        } else if !firstSpot.imageUrl.isEmpty, let url = URL(string: firstSpot.imageUrl) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 91, height: 91)
                                    .clipShape(Circle())
                            } placeholder: {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                    .frame(width: 91, height: 91)
                            }
                        }
                    } else {
                        // デフォルトアイコン
                        Image(systemName: "map.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.blue)
                    }
                }
                .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
                
                // タイトル
                Text(planTitle)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                // アニメ名
                Text(animeName)
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.9))
                
                Spacer()
            }
        }
        .frame(height: 280)
        .ignoresSafeArea(edges: .top) // ステータスバーの領域まで青にする
    }
    
    // プラン情報カード - 日数タブ（新しいデザイン）
    var planInfoCard: some View {
        HStack(spacing: 16) {
            ForEach(1...numberOfDays, id: \.self) { day in
                Button(action: {
                    withAnimation(.spring()) {
                        selectedDay = day
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Day \(day)")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 0.3, green: 0.65, blue: 0.95),
                                        Color(red: 0.2, green: 0.6, blue: 1.0)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
                    )
                    .scaleEffect(selectedDay == day ? 1.05 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedDay)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    // 完了メッセージ
    var completionMessage: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.green)
            
            Text("すべて完了しました！")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.green)
            
            Text("お疲れ様でした")
                .font(.system(size: 16))
                .foregroundColor(.gray)
        }
        .padding(.vertical, 30)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    // 下部のアクションボタン
    var bottomActionButton: some View {
        Button(action: {
            saveVisitProgress()
        }) {
            HStack {
                Image(systemName: "square.and.arrow.down.fill")
                Text("旅をセーブ")
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.black)
            .cornerRadius(8)
        }
    }
    
    func savePlanProgress() {
        // プラン全体を保存
        let planKey = "visit_plan_\(planId?.uuidString ?? planTitle)"
        
        // スポット情報を保存用の辞書に変換
        let spotsData = viewModel.spots.map { spot -> [String: Any] in
            var spotDict: [String: Any] = [
                "id": spot.id.uuidString,
                "name": spot.name,
                "address": spot.address,
                "notes": spot.notes,
                "nearestStation": spot.nearestStation,
                "stayDuration": spot.stayDuration,
                "isCompleted": spot.isCompleted,
                "timeRange": spot.timeRange,
                "activity": spot.activity,
                "dayNumber": spot.dayNumber,
                "spotCost": spot.spotCost,
                "imageUrl": spot.imageUrl,
                "images": spot.images
            ]
            
            // 日付の保存
            if let arrivalTime = spot.arrivalTime {
                spotDict["arrivalTime"] = arrivalTime.timeIntervalSince1970
            }
            if let departureTime = spot.departureTime {
                spotDict["departureTime"] = departureTime.timeIntervalSince1970
            }
            
            // 交通手段の保存
            if let transport = spot.transportToNext {
                spotDict["transportToNext"] = [
                    "method": transport.method,
                    "duration": transport.duration,
                    "cost": transport.cost,
                    "route": transport.route
                ]
            }
            
            // 画像データの保存（Base64エンコード）
            if let imageData = spot.imageData {
                spotDict["imageDataBase64"] = imageData.base64EncodedString()
            }
            
            return spotDict
        }
        
        // プラン全体の情報を保存
        let planData: [String: Any] = [
            "spots": spotsData,
            "lastModified": Date().timeIntervalSince1970
        ]
        
        UserDefaults.standard.set(planData, forKey: planKey)
        print("📝 プランの変更を保存しました - \(viewModel.spots.count)スポット")
    }
    
    func getThumbnailImage() -> UIImage? {
        // 最初のスポットの画像をサムネイルとして使用
        for spot in viewModel.spots {
            if let imageData = spot.imageData, let image = UIImage(data: imageData) {
                return image
            }
        }
        return nil
    }
    
    // 訪問進捗を保存する関数
    func saveVisitProgress() {
        let visitProgressKey = "visit_progress_\(planId?.uuidString ?? planTitle)"
        
        // 現在の訪問済み状態を保存
        let completedSpotIds = viewModel.spots.filter { $0.isCompleted }.map { $0.id.uuidString }
        UserDefaults.standard.set(completedSpotIds, forKey: visitProgressKey)
        
        print("✅ 訪問進捗を保存しました: \(completedSpotIds.count)件")
        
        // 簡単な成功フィードバック
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // ビジットページに戻る
        if let onClose = onClose {
            onClose()
        } else {
            dismiss()
        }
    }
    
    // 保存されたプランデータを読み込む関数
    func loadSavedPlanData() {
        let planKey = "visit_plan_\(planId?.uuidString ?? planTitle)"
        
        guard let planData = UserDefaults.standard.dictionary(forKey: planKey),
              let spotsData = planData["spots"] as? [[String: Any]] else {
            print("📱 保存されたプランデータが見つかりません")
            return
        }
        
        print("📱 保存されたプランデータを読み込み中...")
        
        // 保存されたスポットデータから復元
        var restoredSpots: [VisitSpot] = []
        
        for spotData in spotsData {
            guard let idString = spotData["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let name = spotData["name"] as? String else { continue }
            
            var spot = VisitSpot(
                id: id,
                name: name,
                address: spotData["address"] as? String ?? "",
                notes: spotData["notes"] as? String ?? "",
                nearestStation: spotData["nearestStation"] as? String ?? "",
                stayDuration: spotData["stayDuration"] as? Int ?? 60,
                isCompleted: spotData["isCompleted"] as? Bool ?? false,
                timeRange: spotData["timeRange"] as? String ?? "",
                activity: spotData["activity"] as? String ?? "",
                dayNumber: spotData["dayNumber"] as? Int ?? 1,
                spotCost: spotData["spotCost"] as? Int ?? 0,
                imageUrl: spotData["imageUrl"] as? String ?? "",
                images: spotData["images"] as? [String] ?? []
            )
            
            // 日付の復元
            if let arrivalInterval = spotData["arrivalTime"] as? Double {
                spot.arrivalTime = Date(timeIntervalSince1970: arrivalInterval)
            }
            if let departureInterval = spotData["departureTime"] as? Double {
                spot.departureTime = Date(timeIntervalSince1970: departureInterval)
            }
            
            // 交通手段の復元
            if let transportData = spotData["transportToNext"] as? [String: Any],
               let method = transportData["method"] as? String,
               let duration = transportData["duration"] as? Int,
               let cost = transportData["cost"] as? Int,
               let route = transportData["route"] as? String {
                spot.transportToNext = TransportInfo(
                    method: method,
                    duration: duration,
                    cost: cost,
                    route: route
                )
            }
            
            // 画像データの復元（Base64デコード）
            if let imageDataBase64 = spotData["imageDataBase64"] as? String,
               let imageData = Data(base64Encoded: imageDataBase64) {
                spot.imageData = imageData
            }
            
            restoredSpots.append(spot)
        }
        
        // 復元したスポットで置き換え
        if !restoredSpots.isEmpty {
            viewModel.spots = restoredSpots
            print("📱 プランデータを復元しました - \(restoredSpots.count)スポット")
        }
    }
    
    // ローカルに保存された変更を読み込む関数
    func loadLocalSpotChanges() {
        for i in 0..<viewModel.spots.count {
            let key = "spot_changes_\(viewModel.spots[i].id.uuidString)"
            
            if let changes = UserDefaults.standard.dictionary(forKey: key) {
                print("📱 ローカル変更を読み込み: \(viewModel.spots[i].name)")
                
                if let name = changes["name"] as? String {
                    viewModel.spots[i].name = name
                }
                if let address = changes["address"] as? String {
                    viewModel.spots[i].address = address
                }
                if let notes = changes["notes"] as? String {
                    viewModel.spots[i].notes = notes
                }
                if let activity = changes["activity"] as? String {
                    viewModel.spots[i].activity = activity
                }
                if let stayDuration = changes["stayDuration"] as? Int {
                    viewModel.spots[i].stayDuration = stayDuration
                }
                if let spotCost = changes["spotCost"] as? Int {
                    viewModel.spots[i].spotCost = spotCost
                }
                if let timeRange = changes["timeRange"] as? String {
                    viewModel.spots[i].timeRange = timeRange
                }
                if let arrivalInterval = changes["arrivalTime"] as? Double, arrivalInterval > 0 {
                    viewModel.spots[i].arrivalTime = Date(timeIntervalSince1970: arrivalInterval)
                }
                if let departureInterval = changes["departureTime"] as? Double, departureInterval > 0 {
                    viewModel.spots[i].departureTime = Date(timeIntervalSince1970: departureInterval)
                }
            }
        }
    }
    
    // 訪問進捗を復元する関数
    func loadVisitProgress() {
        let visitProgressKey = "visit_progress_\(planId?.uuidString ?? planTitle)"
        
        if let savedCompletedSpotIds = UserDefaults.standard.array(forKey: visitProgressKey) as? [String] {
            for i in 0..<viewModel.spots.count {
                let spotIdString = viewModel.spots[i].id.uuidString
                if savedCompletedSpotIds.contains(spotIdString) {
                    viewModel.spots[i].isCompleted = true
                }
            }
            print("✅ 訪問進捗を復元しました: \(savedCompletedSpotIds.count)件")
        }
    }
}

// 新しいモダンなスポットカード
// アニメページスタイルのスポットカード
struct AnimeStyleSpotCard: View {
    let spot: VisitSpot
    let isCompleted: Bool
    let onToggle: () -> Void
    let onTap: () -> Void
    let isReadOnly: Bool
    let isFirstSpot: Bool
    let isLastSpot: Bool
    let previousDepartureTime: Date?
    let onEditTransport: (() -> Void)?
    
    let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // 左側のプログレスバー部分
            VStack(spacing: 0) {
                // 上部の線（最初のスポット以外）
                if !isFirstSpot {
                    Rectangle()
                        .fill(isCompleted ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 3, height: 30)
                }
                
                // 円形のマーカー
                Circle()
                    .fill(isCompleted ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 16, height: 16)
                    .overlay(
                        Circle()
                            .fill(Color.white)
                            .frame(width: 8, height: 8)
                    )
                
                // 下部の線（最後のスポット以外）
                if !isLastSpot {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 3)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 40)
            
            // メインコンテンツ
            VStack(alignment: .leading, spacing: 8) {
                // 時刻表示
                HStack(spacing: 4) {
                    if let arrivalTime = spot.arrivalTime {
                        Text(timeFormatter.string(from: arrivalTime))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black)
                        
                        if let departureTime = spot.departureTime {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                            
                            Text(timeFormatter.string(from: departureTime))
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                    } else {
                        // 時刻が設定されていない場合
                        Text("--:--")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.gray.opacity(0.5))
                    }
                }
                
                // スポット情報カード
                HStack(spacing: 12) {
                    // サムネイル
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 100, height: 70)
                        
                        if let imageData = spot.imageData, let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 100, height: 70)
                                .clipped()
                                .cornerRadius(8)
                        } else if !spot.imageUrl.isEmpty, let url = URL(string: spot.imageUrl) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Image(systemName: "photo")
                                    .font(.system(size: 24))
                                    .foregroundColor(.gray)
                            }
                            .frame(width: 100, height: 70)
                            .clipped()
                            .cornerRadius(8)
                        } else {
                            Image(systemName: "photo")
                                .font(.system(size: 24))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // テキスト情報
                    VStack(alignment: .leading, spacing: 4) {
                        Text(spot.name)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                            .lineLimit(1)
                        
                        if !spot.address.isEmpty {
                            Text(spot.address)
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                        
                        // 滞在時間
                        if let arrivalTime = spot.arrivalTime, let departureTime = spot.departureTime {
                            let duration = Int(departureTime.timeIntervalSince(arrivalTime) / 60)
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 11))
                                Text("\(duration)分")
                                    .font(.system(size: 12))
                                
                                if !spot.activity.isEmpty {
                                    Text("• \(spot.activity)")
                                        .font(.system(size: 12))
                                        .lineLimit(1)
                                }
                            }
                            .foregroundColor(.blue)
                        }
                    }
                    
                    Spacer()
                    
                    // 完了ボタン
                    Button(action: onToggle) {
                        Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 24))
                            .foregroundColor(isCompleted ? .green : .gray)
                    }
                    .disabled(isReadOnly)
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(12)
                
                // 交通機関情報（次のスポットがある場合）
                if !isLastSpot {
                    if let transport = spot.transportToNext {
                        HStack(spacing: 8) {
                            // 交通手段アイコン
                            Image(systemName: transport.method == "電車" ? "tram.fill" : 
                                            transport.method == "バス" ? "bus.fill" : 
                                            transport.method == "徒歩" ? "figure.walk" : "car.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.orange)
                            
                            Text(transport.method)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.orange)
                            
                            Text("• \(transport.duration)分")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                            
                            if !transport.route.isEmpty {
                                Text("• \(transport.route)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            // 編集ボタン（読み取り専用でない場合のみ表示）
                            if !isReadOnly {
                                Button(action: {
                                    onEditTransport?()
                                }) {
                                    Image(systemName: "pencil.circle")
                                        .font(.system(size: 16))
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                        .padding(.leading, 30)
                        .padding(.vertical, 8)
                    } else if !isReadOnly {
                        // 交通手段が未設定の場合の追加ボタン
                        Button(action: {
                            onEditTransport?()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 12))
                                Text("交通手段を追加")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.orange, lineWidth: 1)
                            )
                        }
                        .padding(.leading, 30)
                        .padding(.vertical, 8)
                    }
                }
            }
            .padding(.trailing, 16)
        }
        .padding(.leading, 16)
    }
}

struct ModernSpotCard: View {
    let spot: VisitSpot
    let index: Int
    let isCompleted: Bool
    let onToggle: () -> Void
    let onTapImage: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // サムネイル画像（横長に変更）
            Button(action: onTapImage) {
                ZStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 120, height: 80)
                        .cornerRadius(8)
                    
                    if let imageData = spot.imageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 80)
                            .cornerRadius(8)
                            .clipped()
                    } else if !spot.imageUrl.isEmpty, let url = URL(string: spot.imageUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: "photo")
                                .font(.system(size: 30))
                                .foregroundColor(.gray.opacity(0.5))
                        }
                        .frame(width: 120, height: 80)
                        .cornerRadius(8)
                        .clipped()
                    } else {
                        Image(systemName: "photo")
                            .font(.system(size: 30))
                            .foregroundColor(.gray.opacity(0.5))
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // スポット情報
            VStack(alignment: .leading, spacing: 6) {
                Text(spot.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isCompleted ? Color.gray : Color.black)
                    .strikethrough(isCompleted)
                    .lineLimit(1)
                
                if let arrivalTime = spot.arrivalTime {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                        Text(DateFormatter.localizedString(from: arrivalTime, dateStyle: .none, timeStyle: .short))
                            .font(.system(size: 13))
                    }
                    .foregroundColor(.gray)
                }
                
                if !spot.address.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "location")
                            .font(.system(size: 12))
                        Text(spot.address)
                            .font(.system(size: 13))
                            .lineLimit(1)
                    }
                    .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // チェックボタン
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .stroke(isCompleted ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 30, height: 30)
                    
                    if isCompleted {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 30, height: 30)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .scaleEffect(isCompleted ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCompleted)
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
                    if let imageData = spot.imageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 140, height: 100)
                            .clipped()
                            .cornerRadius(8)
                    } else if !spot.imageUrl.isEmpty || !spot.images.isEmpty {
                        let imageUrlToUse = !spot.imageUrl.isEmpty ? spot.imageUrl : (spot.images.first ?? "")
                        
                        if let url = URL(string: imageUrlToUse), !imageUrlToUse.isEmpty {
                            CustomAsyncImage(url: url, width: 140, height: 100)
                                .cornerRadius(8)
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.orange)
                                .frame(width: 140, height: 100)
                                .overlay(
                                    Image(systemName: "exclamationmark.triangle")
                                        .font(.system(size: 30))
                                        .foregroundColor(.white)
                                )
                        }
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue)
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
                    
                    // 到着・出発時間
                    HStack(spacing: 8) {
                        if let arrivalTime = spot.arrivalTime {
                            Label(timeFormatter.string(from: arrivalTime), systemImage: "arrow.down.circle.fill")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.green)
                        }
                        
                        if let departureTime = spot.departureTime {
                            Label(timeFormatter.string(from: departureTime), systemImage: "arrow.up.circle.fill")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.red)
                        }
                        
                        // 既存の時間帯表示も残す
                        if !spot.timeRange.isEmpty && spot.arrivalTime == nil && spot.departureTime == nil {
                            Text(spot.timeRange)
                                .font(.system(size: 12))
                                .foregroundColor(.blue)
                        }
                    }
                    
                    // プログレスバー（現在時刻が到着・出発時間の間にある場合に表示）
                    if let arrivalTime = spot.arrivalTime, let departureTime = spot.departureTime {
                        let now = Date()
                        let totalDuration = departureTime.timeIntervalSince(arrivalTime)
                        let elapsedTime = now.timeIntervalSince(arrivalTime)
                        let progress = min(max(elapsedTime / totalDuration, 0), 1)
                        
                        if progress >= 0 && progress <= 1 {
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    // 背景
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 4)
                                    
                                    // 進捗
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.purple)
                                        .frame(width: geometry.size.width * CGFloat(progress), height: 4)
                                        .animation(.linear(duration: 0.3), value: progress)
                                }
                            }
                            .frame(height: 4)
                            .padding(.top, 2)
                        }
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
                    print("🔘 DEBUG: SpotCard - チェックボックスが押されました")
                    print("  - スポット名: \(spot.name)")
                    print("  - 現在のisCompleted (プロパティ): \(isCompleted)")
                    print("  - spot.isCompleted: \(spot.isCompleted)")
                    print("  - spot.id: \(spot.id)")
                    
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

struct SpotDetailPageView: View {
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
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    // 中央のコンテンツ
                    VStack(spacing: 16) {
                        // 丸いアイコン（サイズを調整）
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 108, height: 108)
                                .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                            
                            if let imageData = spot.imageData, let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 94, height: 94)
                                    .clipShape(Circle())
                            } else if !spot.imageUrl.isEmpty || !spot.images.isEmpty {
                                let imageUrlToUse = !spot.imageUrl.isEmpty ? spot.imageUrl : (spot.images.first ?? "")
                                
                                if let url = URL(string: imageUrlToUse), !imageUrlToUse.isEmpty {
                                    AsyncImage(url: url) { image in
                                        image
                                            .resizable()
                                            .scaledToFill()
                                    } placeholder: {
                                        Image(systemName: "photo")
                                            .font(.system(size: 29))
                                            .foregroundColor(.gray)
                                    }
                                    .frame(width: 94, height: 94)
                                    .clipShape(Circle())
                                } else {
                                    Image(systemName: "photo")
                                        .font(.system(size: 29))
                                        .foregroundColor(.gray)
                                }
                            } else {
                                Image(systemName: "photo")
                                    .font(.system(size: 24))
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        // スポット名（中央配置）
                        VStack(spacing: 4) {
                            Text(spot.name)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.black)
                                .multilineTextAlignment(.center)
                            
                            if !spot.address.isEmpty {
                                Text(spot.address)
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(1)
                            }
                            
                            // 地図アイコン
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 19))
                                .foregroundColor(.blue)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 20)
                
                // 白いコンテンツ領域
                VStack(alignment: .leading, spacing: 20) {
                    // 滞在時間帯
                    if !spot.timeRange.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("滞在時間帯")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 14))
                                Text(spot.timeRange)
                                    .font(.system(size: 16))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    
                    // ここで何をするのか
                    if !spot.activity.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ここで何をするのか")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                            Text(spot.activity)
                                .font(.system(size: 16))
                                .foregroundColor(.black)
                        }
                    }
                    
                    // 情報テーブル
                    VStack(spacing: 12) {
                        // 滞在時間
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.blue)
                                .font(.system(size: 16))
                                .frame(width: 20)
                            Text("滞在時間")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                                .frame(width: 80, alignment: .leading)
                            Text("\(spot.stayDuration)分")
                                .font(.system(size: 16))
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        // 住所
                        if !spot.address.isEmpty {
                            HStack {
                                Image(systemName: "mappin")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 16))
                                    .frame(width: 20)
                                Text("住所")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                    .frame(width: 80, alignment: .leading)
                                Text(spot.address)
                                    .font(.system(size: 16))
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        
                        // スポット費用
                        if spot.spotCost > 0 {
                            HStack {
                                Image(systemName: "yensign.circle")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 16))
                                    .frame(width: 20)
                                Text("費用")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                    .frame(width: 80, alignment: .leading)
                                Text("¥\(spot.spotCost)")
                                    .font(.system(size: 16))
                                    .foregroundColor(.blue)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    
                    // メモ
                    if !spot.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("メモ")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                            Text(spot.notes)
                                .font(.system(size: 16))
                                .foregroundColor(.black)
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
                            HStack {
                                Image(systemName: "map")
                                Text("地図で開く")
                            }
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .cornerRadius(8)
                        }
                    }
                }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 100)
                    .background(Color.white)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.black)
                }
            }
            ToolbarItem(placement: .principal) {
                Text(spot.name)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingEditSheet = true
                }) {
                    Text("Change")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black)
                        .cornerRadius(6)
                }
            }
        }
        .toolbarBackground(Color.white, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .background(Color(.systemBackground))
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
                        showingEditSheet = false
                        savePlanProgress()
                    },
                    onCancel: {
                        showingEditSheet = false
                    }
                )
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

// 全日程完了時のポップアップビュー
// スポット追加ビュー
struct GameAddSpotView: View {
    let animeName: String
    let selectedDay: Int
    let onSave: (VisitSpot) -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var address = ""
    @State private var activity = ""
    @State private var stayDuration = 60
    @State private var spotCost = 0
    @State private var notes = ""
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("基本情報")) {
                    TextField("スポット名", text: $name)
                    TextField("住所", text: $address)
                    TextField("アクティビティ", text: $activity)
                }
                
                Section(header: Text("詳細")) {
                    Stepper("滞在時間: \(stayDuration)分", value: $stayDuration, in: 15...480, step: 15)
                    
                    HStack {
                        Text("費用")
                        Spacer()
                        TextField("0", value: $spotCost, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text("円")
                    }
                    
                    TextField("メモ", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section(header: Text("画像")) {
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .onTapGesture {
                                showImagePicker = true
                            }
                    } else {
                        Button(action: {
                            showImagePicker = true
                        }) {
                            HStack {
                                Image(systemName: "photo")
                                Text("画像を選択")
                            }
                        }
                    }
                }
            }
            .navigationTitle("スポットを追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        let newSpot = VisitSpot(
                            name: name,
                            address: address,
                            notes: notes,
                            stayDuration: stayDuration,
                            activity: activity,
                            imageData: selectedImage?.jpegData(compressionQuality: 0.8),
                            dayNumber: selectedDay,
                            spotCost: spotCost
                        )
                        onSave(newSpot)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedImage)
        }
    }
}

// 交通手段追加/編集ビュー
struct GameAddTransportView: View {
    let transport: TransportInfo?
    let onSave: (TransportInfo) -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var method: String = "電車"
    @State private var duration: Int = 30
    @State private var cost: Int = 0
    @State private var route: String = ""
    
    let transportMethods = ["電車", "バス", "徒歩", "タクシー", "車", "自転車"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("交通手段")) {
                    Picker("移動方法", selection: $method) {
                        ForEach(transportMethods, id: \.self) { method in
                            Text(method).tag(method)
                        }
                    }
                    
                    Stepper("移動時間: \(duration)分", value: $duration, in: 5...180, step: 5)
                    
                    HStack {
                        Text("交通費")
                        Spacer()
                        TextField("0", value: $cost, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        Text("円")
                    }
                    
                    TextField("経路情報（例：JR山手線→東西線）", text: $route)
                }
            }
            .navigationTitle("交通手段")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        let newTransport = TransportInfo(
                            method: method,
                            duration: duration,
                            cost: cost,
                            route: route
                        )
                        onSave(newTransport)
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            if let transport = transport {
                method = transport.method
                duration = transport.duration
                cost = transport.cost
                route = transport.route
            }
        }
    }
}

// 画像ピッカー
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

struct ImprovedCompletionView: View {
    @Binding var isPresented: Bool
    let planTitle: String
    let animeName: String
    let thumbnail: UIImage?
    
    @State private var showCelebration = false
    @State private var showParticles = false
    @State private var scale: CGFloat = 0.3
    @State private var opacity: Double = 0.0
    @State private var cardOffset: CGFloat = 50
    @State private var particlesOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // エフェクト背景（透明度を下げて元のページが見える）
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            // パーティクルエフェクト
            if showParticles {
                ForEach(0..<20, id: \.self) { index in
                    Circle()
                        .fill(Color.random)
                        .frame(width: CGFloat.random(in: 4...8), height: CGFloat.random(in: 4...8))
                        .position(
                            x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                            y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                        )
                        .offset(y: particlesOffset)
                        .animation(.easeInOut(duration: Double.random(in: 2...4)).delay(Double.random(in: 0...1)), value: particlesOffset)
                }
            }
            
            // メインカード
            VStack(spacing: 20) {
                // 完了アイコンとエフェクト
                ZStack {
                    // 背景の輝きエフェクト
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color.yellow.opacity(0.6),
                                    Color.orange.opacity(0.4),
                                    Color.clear
                                ]),
                                center: .center,
                                startRadius: 20,
                                endRadius: 80
                            )
                        )
                        .frame(width: 120, height: 120)
                        .scaleEffect(showCelebration ? 1.3 : 1.0)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: showCelebration)
                    
                    // チェックマークアイコン
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                        .scaleEffect(scale)
                        .shadow(radius: 10)
                }
                
                // プランサムネイル
                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 200, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                        .scaleEffect(scale)
                }
                
                // 完了テキスト
                VStack(spacing: 8) {
                    Text("🎉 お疲れ様でした！")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text(planTitle)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text("アニメ：\(animeName)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                }
                .opacity(opacity)
                
                // 閉じるボタン
                Button(action: dismissView) {
                    HStack {
                        Image(systemName: "checkmark")
                        Text("完了")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.purple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(25)
                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .scaleEffect(scale)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            )
            .scaleEffect(scale)
            .offset(y: cardOffset)
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // 順次アニメーション
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
            scale = 1.0
            cardOffset = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeInOut(duration: 0.6)) {
                opacity = 1.0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showCelebration = true
            showParticles = true
            withAnimation(.easeInOut(duration: 3.0)) {
                particlesOffset = -UIScreen.main.bounds.height
            }
        }
    }
    
    private func dismissView() {
        withAnimation(.easeInOut(duration: 0.3)) {
            scale = 0.3
            opacity = 0.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isPresented = false
        }
    }
}

// ランダムカラー拡張
extension Color {
    static var random: Color {
        return Color(
            red: .random(in: 0...1),
            green: .random(in: 0...1),
            blue: .random(in: 0...1)
        )
    }
}

struct AllDaysCompletionView: View {
    @Binding var isPresented: Bool
    let planTitle: String
    @State private var showCelebration = false
    @State private var showConfetti = false
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0.0
    
    var body: some View {
        ZStack {
            // 背景
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissView()
                }
            
            // メインコンテンツ
            VStack(spacing: 24) {
                // 完了アイコン
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [Color.green.opacity(0.3), Color.green.opacity(0.1)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 120, height: 120)
                        .scaleEffect(showCelebration ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: showCelebration)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                        .scaleEffect(scale)
                        .animation(.spring(response: 0.8, dampingFraction: 0.6), value: scale)
                }
                
                // タイトル
                Text("お疲れ様でした！")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .opacity(opacity)
                    .animation(.easeInOut(duration: 0.8).delay(0.3), value: opacity)
                
                // プラン名
                Text(planTitle)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .opacity(opacity)
                    .animation(.easeInOut(duration: 0.8).delay(0.5), value: opacity)
                
                // 完了メッセージ
                Text("すべての日程が完了しました")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .opacity(opacity)
                    .animation(.easeInOut(duration: 0.8).delay(0.7), value: opacity)
                
                // 閉じるボタン
                Button(action: {
                    dismissView()
                }) {
                    Text("閉じる")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.green, Color.green.opacity(0.8)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: Color.green.opacity(0.3), radius: 5, x: 0, y: 3)
                }
                .opacity(opacity)
                .animation(.easeInOut(duration: 0.8).delay(0.9), value: opacity)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.8))
                    .blur(radius: 0.5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal, 40)
            .scaleEffect(scale)
            .opacity(opacity)
            
            // 紙吹雪エフェクト
            if showConfetti {
                ForEach(0..<20, id: \.self) { index in
                    ConfettiPiece(index: index)
                }
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // 初期表示アニメーション
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            scale = 1.0
            opacity = 1.0
        }
        
        // 祝福アニメーション開始
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showCelebration = true
            showConfetti = true
        }
        
        // ハプティックフィードバック
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        // 紙吹雪を一定時間後に停止
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            showConfetti = false
        }
    }
    
    private func dismissView() {
        withAnimation(.easeInOut(duration: 0.3)) {
            scale = 0.5
            opacity = 0.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isPresented = false
        }
    }
}

// 紙吹雪のピース
struct ConfettiPiece: View {
    let index: Int
    @State private var yPosition: CGFloat = -100
    @State private var xPosition: CGFloat = 0
    @State private var rotation: Double = 0
    @State private var opacity: Double = 1.0
    
    private let colors = [Color.yellow, Color.pink, Color.blue, Color.green, Color.orange, Color.purple]
    
    var body: some View {
        Rectangle()
            .fill(colors[index % colors.count])
            .frame(width: 8, height: 8)
            .rotationEffect(.degrees(rotation))
            .opacity(opacity)
            .position(x: xPosition, y: yPosition)
            .onAppear {
                // 初期位置設定
                xPosition = CGFloat.random(in: 50...350)
                
                // アニメーション開始
                withAnimation(.linear(duration: Double.random(in: 2...4))) {
                    yPosition = UIScreen.main.bounds.height + 100
                    rotation = Double.random(in: 0...360)
                }
                
                // フェードアウト
                withAnimation(.easeOut(duration: 1.0).delay(1.5)) {
                    opacity = 0.0
                }
            }
    }
}

// Streaming Services Sheet
struct StreamingServicesSheet: View {
    let animeName: String
    let streamingServices: [StreamingService]
    @Binding var isPresented: Bool
    let thumbnailUrl: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    // プランのサムネイル
                    if let thumbnailUrl = thumbnailUrl,
                       let url = URL(string: thumbnailUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipped()
                                .cornerRadius(12)
                        } placeholder: {
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .frame(width: 80, height: 80)
                                .cornerRadius(12)
                                .overlay(
                                    ProgressView()
                                        .scaleEffect(0.7)
                                )
                        }
                    }
                    
                    VStack(spacing: 8) {
                        Text("アニメを観る")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.black)
                        
                        Text(animeName)
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 16)
                
                ScrollView {
                    VStack(spacing: 12) {
                        if streamingServices.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "tv.slash")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                                Text("ストリーミングサービスが設定されていません")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                Text("管理者による設定が必要です")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.vertical, 40)
                        } else {
                            ForEach(Array(streamingServices.enumerated()), id: \.offset) { index, service in
                                StreamingServiceRow(service: service)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                
                // Close button
                Button(action: {
                    isPresented = false
                }) {
                    Text("閉じる")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.black)
                        .cornerRadius(8)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .background(Color(.systemBackground))
            .navigationBarHidden(true)
        }
    }
}

struct StreamingServiceRow: View {
    let service: StreamingService
    
    var body: some View {
        Button(action: {
            if let url = URL(string: service.url) {
                UIApplication.shared.open(url)
            }
        }) {
            HStack(spacing: 16) {
                // Service icon or default play icon
                ZStack {
                    Circle()
                        .fill(serviceColor(for: service.name))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: serviceIcon(for: service.name))
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(service.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                    
                    Text("タップして視聴")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
            }
            .padding(16)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    func serviceColor(for name: String) -> Color {
        switch name.lowercased() {
        case "netflix":
            return Color.red
        case "amazon prime", "prime video":
            return Color.blue
        case "disney+", "disney plus":
            return Color(red: 0.0, green: 0.3, blue: 0.7)
        case "hulu":
            return Color.green
        case "u-next":
            return Color.orange
        case "abema":
            return Color.purple
        default:
            return Color.gray
        }
    }
    
    func serviceIcon(for name: String) -> String {
        switch name.lowercased() {
        case "netflix", "amazon prime", "prime video", "disney+", "disney plus", "hulu", "u-next", "abema":
            return "play.fill"
        default:
            return "play.circle.fill"
        }
    }
}