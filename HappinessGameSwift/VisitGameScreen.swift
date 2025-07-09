import SwiftUI

struct VisitGameScreen: View {
    @Environment(\.dismiss) var dismiss
    let animeName: String
    let duration: String
    @State var spots: [VisitSpot]
    @State private var currentSpotIndex = 0
    @State private var showingDetail = false
    @State private var selectedSpot: VisitSpot?
    
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
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ヘッダー
                HStack {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .medium))
                        }
                        .foregroundColor(.gray)
                        .padding(8)
                        .background(Circle().fill(Color(.systemGray5)))
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 4) {
                        Text(animeName)
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        Text(duration)
                            .font(.system(size: 18, weight: .semibold))
                    }
                    
                    Spacer()
                    
                    // 進捗表示
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                        Circle()
                            .trim(from: 0, to: CGFloat(completedSpotsCount) / CGFloat(spots.count))
                            .stroke(Color.green, lineWidth: 4)
                            .rotationEffect(.degrees(-90))
                        Text("\(completedSpotsCount)/\(spots.count)")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .frame(width: 50, height: 50)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
                
                ScrollView {
                    VStack(spacing: 0) {
                        // 現在時刻と開始時刻の表示
                        if let firstSpot = spots.first, let startTime = firstSpot.arrivalTime {
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
                        ForEach(Array(spots.enumerated()), id: \.element.id) { index, spot in
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
                                        toggleSpotCompletion(at: index)
                                    }
                                )
                                
                                // 交通機関情報
                                if index < spots.count - 1, let transport = spot.transportToNext {
                                    TransportCard(transport: transport)
                                }
                            }
                        }
                        
                        // 完了メッセージ
                        if completedSpotsCount == spots.count {
                            VStack(spacing: 16) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.green)
                                Text("すべてのスポットを巡りました！")
                                    .font(.system(size: 20, weight: .semibold))
                                Text("お疲れ様でした")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
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
                        dismiss()
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
            SpotDetailView(spot: spot)
        }
    }
    
    func toggleSpotCompletion(at index: Int) {
        spots[index].isCompleted.toggle()
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
        HStack(spacing: 16) {
            // チェックボックス
            Button(action: onToggle) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isCompleted ? .green : .gray)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                // 時刻と名前
                HStack {
                    if let arrivalTime = spot.arrivalTime {
                        Text(timeFormatter.string(from: arrivalTime))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    Text(spot.name)
                        .font(.system(size: 16, weight: .semibold))
                        .strikethrough(isCompleted)
                        .foregroundColor(isCompleted ? .gray : .primary)
                }
                
                // 最寄り駅
                if !spot.nearestStation.isEmpty {
                    Label(spot.nearestStation, systemImage: "tram")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                // 滞在時間とメモ
                HStack {
                    Label("\(spot.stayDuration)分", systemImage: "clock")
                        .font(.system(size: 13))
                        .foregroundColor(.orange)
                    
                    if !spot.notes.isEmpty {
                        Text("・")
                            .foregroundColor(.gray)
                        Text(spot.notes)
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            // 詳細ボタン
            Button(action: onTap) {
                Image(systemName: "info.circle")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
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
    let spot: VisitSpot
    
    let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // スポット名
                    VStack(alignment: .leading, spacing: 8) {
                        Text("スポット名")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        Text(spot.name)
                            .font(.system(size: 20, weight: .semibold))
                    }
                    
                    // 時刻情報
                    if let arrivalTime = spot.arrivalTime, let departureTime = spot.departureTime {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("時刻")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                            HStack(spacing: 16) {
                                Label("到着: \(timeFormatter.string(from: arrivalTime))", systemImage: "arrow.down.circle")
                                Label("出発: \(timeFormatter.string(from: departureTime))", systemImage: "arrow.up.circle")
                            }
                            .font(.system(size: 16))
                        }
                    }
                    
                    // 最寄り駅
                    if !spot.nearestStation.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("最寄り駅")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                            Label(spot.nearestStation, systemImage: "tram")
                                .font(.system(size: 16))
                        }
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
                    
                    // 滞在時間
                    VStack(alignment: .leading, spacing: 8) {
                        Text("滞在時間")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        Label("\(spot.stayDuration)分", systemImage: "clock")
                            .font(.system(size: 16))
                            .foregroundColor(.orange)
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
                .padding(16)
            }
            .navigationTitle("スポット詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
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