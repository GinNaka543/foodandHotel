import SwiftUI

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
    let numberOfDays: Int
    let startTime: Date
    let onClose: (() -> Void)?
    
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
    
    var body: some View {
        let _ = print("🎮 [DEBUG] VisitGameScreen.body 呼び出し")
        let _ = print("🎮 [DEBUG] planTitle: \(planTitle)")
        let _ = print("🎮 [DEBUG] animeName: \(animeName)")
        let _ = print("🎮 [DEBUG] spots.count: \(spots.count)")
        let _ = print("🎮 [DEBUG] numberOfDays: \(numberOfDays)")
        let _ = print("🎮 [DEBUG] spots dayNumber distribution:")
        for spot in spots {
            print("  - \(spot.name): day \(spot.dayNumber)")
        }
        
        return NavigationView {
            VStack(spacing: 0) {
                // ヘッダー
                HStack {
                    Button(action: { 
                        if let onClose = onClose {
                            onClose()
                        } else {
                            dismiss()
                        }
                    }) {
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
                            .stroke(Color.green, lineWidth: 4)
                            .rotationEffect(.degrees(-90))
                        Text("\(filteredSpotsCompletedCount)/\(filteredSpotsCount)")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .frame(width: 50, height: 50)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
                
                // 日数が2日以上の場合はタブ表示
                if numberOfDays > 1 {
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
                
                ScrollView {
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
                        ForEach(Array(filteredSpots.enumerated()), id: \.element.id) { index, spot in
                            VStack(spacing: 0) {
                                SpotCard(
                                    spot: spot,
                                    index: index,
                                    isCompleted: spot.isCompleted,
                                    onTap: {
                                        selectedSpot = spot
                                        showingDetail = true
                                    },
                                    onToggle: {
                                        toggleSpotCompletion(spotId: spot.id)
                                    }
                                )
                                
                                // 交通機関情報
                                if index < filteredSpots.count - 1, let transport = spot.transportToNext {
                                    TransportCard(transport: transport)
                                }
                            }
                        }
                        
                        // 完了メッセージ
                        if filteredSpotsCount > 0 && filteredSpotsCompletedCount == filteredSpotsCount {
                            VStack(spacing: 16) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.green)
                                Text("Day \(selectedDay)のスポットを\nすべて巡りました！")
                                    .font(.system(size: 20, weight: .semibold))
                                    .multilineTextAlignment(.center)
                                if completedSpotsCount == spots.count {
                                    Text("すべての日程が完了しました\nお疲れ様でした")
                                        .font(.system(size: 16))
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .padding(.vertical, 40)
                        }
                    }
                    .padding(.bottom, 100)
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
                SpotDetailView(spot: $spots[index], spots: $spots, startTime: startTime)
            }
        }
        .onAppear {
            print("DEBUG: VisitGameScreen表示")
            print("  - planTitle: \(planTitle)")
            print("  - animeName: \(animeName)")
            print("  - spots count: \(spots.count)")
            print("  - numberOfDays: \(numberOfDays)")
            if spots.isEmpty {
                print("⚠️ WARNING: spotsが空です！")
            }
        }
        .background(Color(.systemBackground))
    }
    
    func toggleSpotCompletion(spotId: UUID) {
        if let index = spots.firstIndex(where: { $0.id == spotId }) {
            spots[index].isCompleted.toggle()
        }
    }
}

struct SpotCard: View {
    let spot: VisitSpot
    let index: Int
    let isCompleted: Bool
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
                    } else if !spot.imageUrl.isEmpty {
                        // Web管理画面から作成されたプランの画像を表示
                        AsyncImage(url: URL(string: spot.imageUrl)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 140, height: 100)
                                    .clipped()
                                    .cornerRadius(8)
                            case .failure(_):
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray5))
                                    .frame(width: 140, height: 100)
                                    .overlay(
                                        Image(systemName: "exclamationmark.triangle")
                                            .font(.system(size: 30))
                                            .foregroundColor(.gray)
                                    )
                            case .empty:
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray5))
                                    .frame(width: 140, height: 100)
                                    .overlay(
                                        ProgressView()
                                    )
                            @unknown default:
                                EmptyView()
                            }
                        }
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray5))
                            .frame(width: 140, height: 100)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.system(size: 30))
                                    .foregroundColor(.gray)
                            )
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
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
                Button(action: onToggle) {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24))
                        .foregroundColor(isCompleted ? .green : .gray)
                }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
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
    @State private var selectedImageData: Data? = nil
    @State private var showingFullScreenImage = false
    @State private var showingEditSheet = false
    
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
                    } else if !spot.imageUrl.isEmpty {
                        // Web管理画面から作成されたプランの画像を表示
                        AsyncImage(url: URL(string: spot.imageUrl)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 200)
                                    .clipped()
                                    .cornerRadius(12)
                            case .failure(_):
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray5))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 200)
                                    .overlay(
                                        Image(systemName: "exclamationmark.triangle")
                                            .font(.system(size: 40))
                                            .foregroundColor(.gray)
                                    )
                            case .empty:
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGray5))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 200)
                                    .overlay(
                                        ProgressView()
                                    )
                            @unknown default:
                                EmptyView()
                            }
                        }
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
                    if let detailImagesData = spot.detailImagesData, !detailImagesData.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("詳細画像")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
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
            .navigationTitle("スポット詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("編集") {
                        showingEditSheet = true
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showingFullScreenImage) {
            if let imageData = selectedImageData, let uiImage = UIImage(data: imageData) {
                FullScreenImageView(image: uiImage, isPresented: $showingFullScreenImage)
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditSpotView(spot: spot, spots: $spots, startTime: startTime)
        }
    }
    
    func openInMaps(address: String) {
        let encodedAddress = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "maps://?q=\(encodedAddress)") {
            UIApplication.shared.open(url)
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