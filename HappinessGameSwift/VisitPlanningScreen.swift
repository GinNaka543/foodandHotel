import SwiftUI
import PhotosUI
import Foundation

struct VisitPlanningScreen: View {
    @Environment(\.dismiss) var dismiss
    @State private var spots: [VisitSpot] = []
    @State private var showingAddSpotSheet = false
    @State private var animeName: String = ""
    @State private var planTitle: String = ""
    @State private var showingItinerary = false
    @State private var selectedImage: PhotosPickerItem?
    @State private var thumbnailImage: UIImage?
    @State private var thumbnailData: Data?
    @State private var startTime = Date()
    @State private var editingSpot: VisitSpot?
    
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
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ヘッダー
                HStack {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20, weight: .medium))
                            Text("Back")
                                .font(.system(size: 17, weight: .medium))
                        }
                        .foregroundColor(.blue)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 基本情報入力
                        VStack(spacing: 16) {
                            // タイトル入力
                            VStack(alignment: .leading, spacing: 8) {
                                Text("プランタイトル")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.gray)
                                TextField("例: 京都の聖地巡礼", text: $planTitle)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .font(.system(size: 16))
                            }
                            
                            // アニメ名入力
                            VStack(alignment: .leading, spacing: 8) {
                                Text("アニメ名")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.gray)
                                TextField("例: 響け！ユーフォニアム", text: $animeName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .font(.system(size: 16))
                            }
                            
                            // 開始時刻
                            VStack(alignment: .leading, spacing: 8) {
                                Text("開始時刻")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.gray)
                                DatePicker("", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                                    .datePickerStyle(CompactDatePickerStyle())
                                    .labelsHidden()
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        // サムネイル選択
                        VStack(alignment: .leading, spacing: 8) {
                            Text("サムネイル画像")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 16)
                            
                            PhotosPicker(selection: $selectedImage,
                                       matching: .images,
                                       photoLibrary: .shared()) {
                                if let thumbnailImage = thumbnailImage {
                                    Image(uiImage: thumbnailImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 180)
                                        .clipped()
                                        .cornerRadius(12)
                                } else {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.systemGray5))
                                        .frame(height: 180)
                                        .overlay(
                                            VStack(spacing: 8) {
                                                Image(systemName: "photo")
                                                    .font(.system(size: 40))
                                                    .foregroundColor(.gray)
                                                Text("画像を選択")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.gray)
                                            }
                                        )
                                }
                            }
                            .padding(.horizontal, 16)
                            .onChange(of: selectedImage) { newItem in
                                Task {
                                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                        thumbnailImage = UIImage(data: data)
                                        thumbnailData = data
                                    }
                                }
                            }
                        }
                        
                        // タイムライン
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("タイムライン")
                                    .font(.system(size: 18, weight: .semibold))
                                Spacer()
                                Button(action: { showingAddSpotSheet = true }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus")
                                        Text("追加")
                                    }
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue)
                                    .cornerRadius(16)
                                }
                            }
                            .padding(.horizontal, 16)
                            
                            if spots.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.system(size: 40))
                                        .foregroundColor(.gray)
                                    Text("スポットを追加して旅程を作成")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(Array(spots.enumerated()), id: \.element.id) { index, spot in
                                        TimelineItem(
                                            spot: spot,
                                            index: index,
                                            totalSpots: spots.count,
                                            startTime: startTime,
                                            previousSpots: Array(spots.prefix(index))
                                        )
                                        .onTapGesture {
                                            editingSpot = spot
                                        }
                                        
                                        if index < spots.count - 1 {
                                            TransportView(
                                                from: spot,
                                                to: spots[index + 1]
                                            )
                                        }
                                    }
                                }
                            }
                        }
                        
                        // 概要情報
                        if !spots.isEmpty {
                            VStack(spacing: 8) {
                                HStack {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(.blue)
                                    Text("概要")
                                        .font(.system(size: 16, weight: .semibold))
                                    Spacer()
                                }
                                HStack {
                                    Label("総移動時間", systemImage: "clock")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Text(formatTotalDuration())
                                        .font(.system(size: 14, weight: .medium))
                                }
                                HStack {
                                    Label("予想費用", systemImage: "yensign.circle")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Text("¥\(calculateTotalCost())")
                                        .font(.system(size: 14, weight: .medium))
                                }
                            }
                            .padding(16)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                        }
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.top, 16)
                }
                
                // 下部のボタン
                HStack(spacing: 16) {
                    Button(action: {
                        savePlan()
                        dismiss()
                    }) {
                        Text("保存")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.blue)
                            )
                    }
                    .disabled(planTitle.isEmpty || animeName.isEmpty)
                    
                    Button(action: {
                        showingItinerary = true
                    }) {
                        Text("旅程を確認")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.green)
                            )
                    }
                    .disabled(spots.isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingAddSpotSheet) {
            AddSpotView(spots: $spots, startTime: startTime, previousSpots: spots)
        }
        .sheet(item: $editingSpot) { spot in
            EditSpotView(spot: spot, spots: $spots, startTime: startTime)
        }
        .fullScreenCover(isPresented: $showingItinerary) {
            VisitGameScreen(
                animeName: animeName,
                duration: formatTotalDuration(),
                spots: updateSpotTimes()
            )
        }
    }
    
    func updateSpotTimes() -> [VisitSpot] {
        var updatedSpots = spots
        var currentTime = startTime
        
        for i in 0..<updatedSpots.count {
            updatedSpots[i].arrivalTime = currentTime
            currentTime = currentTime.addingTimeInterval(TimeInterval(updatedSpots[i].stayDuration * 60))
            updatedSpots[i].departureTime = currentTime
            
            if i < updatedSpots.count - 1, let transport = updatedSpots[i].transportToNext {
                currentTime = currentTime.addingTimeInterval(TimeInterval(transport.duration * 60))
            }
        }
        
        return updatedSpots
    }
    
    func calculateTotalCost() -> Int {
        spots.reduce(0) { total, spot in
            total + (spot.transportToNext?.cost ?? 0)
        }
    }
    
    func formatTotalDuration() -> String {
        let totalMinutes = spots.reduce(0) { total, spot in
            total + spot.stayDuration + (spot.transportToNext?.duration ?? 0)
        }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours > 0 {
            return "\(hours)時間\(minutes)分"
        } else {
            return "\(minutes)分"
        }
    }
    
    func savePlan() {
        let plan = VisitPlanData(
            animeName: animeName,
            title: planTitle,
            duration: formatTotalDuration(),
            spots: updateSpotTimes(),
            thumbnailData: thumbnailData,
            startTime: startTime
        )
        
        var savedPlans = getSavedPlans()
        savedPlans.append(plan)
        
        if let encoded = try? JSONEncoder().encode(savedPlans) {
            UserDefaults.standard.set(encoded, forKey: "visitPlans")
        }
    }
    
    func getSavedPlans() -> [VisitPlanData] {
        guard let data = UserDefaults.standard.data(forKey: "visitPlans"),
              let plans = try? JSONDecoder().decode([VisitPlanData].self, from: data) else {
            return []
        }
        return plans
    }
}

struct TimelineItem: View {
    let spot: VisitSpot
    let index: Int
    let totalSpots: Int
    let startTime: Date
    let previousSpots: [VisitSpot]
    
    var arrivalTime: String {
        var time = startTime
        for prevSpot in previousSpots {
            time = time.addingTimeInterval(TimeInterval(prevSpot.stayDuration * 60))
            if let transport = prevSpot.transportToNext {
                time = time.addingTimeInterval(TimeInterval(transport.duration * 60))
            }
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: time)
    }
    
    var departureTime: String {
        var time = startTime
        for prevSpot in previousSpots {
            time = time.addingTimeInterval(TimeInterval(prevSpot.stayDuration * 60))
            if let transport = prevSpot.transportToNext {
                time = time.addingTimeInterval(TimeInterval(transport.duration * 60))
            }
        }
        time = time.addingTimeInterval(TimeInterval(spot.stayDuration * 60))
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: time)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // 時刻表示
            VStack(spacing: 4) {
                Text(arrivalTime)
                    .font(.system(size: 14, weight: .medium))
                Text("↓")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                Text(departureTime)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
            }
            .frame(width: 50)
            
            // タイムラインバー
            VStack(spacing: 0) {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 12, height: 12)
                if index < totalSpots - 1 {
                    Rectangle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: 2)
                }
            }
            
            // スポット情報
            VStack(alignment: .leading, spacing: 8) {
                Text(spot.name)
                    .font(.system(size: 16, weight: .semibold))
                
                if !spot.nearestStation.isEmpty {
                    Label(spot.nearestStation, systemImage: "tram")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                if !spot.address.isEmpty {
                    Label(spot.address, systemImage: "mappin")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                HStack {
                    Label("\(spot.stayDuration)分", systemImage: "clock")
                        .font(.system(size: 13))
                        .foregroundColor(.blue)
                    
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
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
        }
        .padding(.horizontal, 16)
    }
}

struct TransportView: View {
    let from: VisitSpot
    let to: VisitSpot
    
    var body: some View {
        if let transport = from.transportToNext {
            HStack(spacing: 16) {
                Spacer()
                    .frame(width: 50)
                
                Rectangle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: 2, height: 60)
                    .padding(.leading, 5)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: transportIcon(transport.method))
                            .font(.system(size: 14))
                            .foregroundColor(.orange)
                        Text(transport.method)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.orange)
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
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
            }
            .padding(.horizontal, 16)
        }
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

struct AddSpotView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var spots: [VisitSpot]
    let startTime: Date
    let previousSpots: [VisitSpot]
    
    @State private var spotName: String = ""
    @State private var spotAddress: String = ""
    @State private var nearestStation: String = ""
    @State private var stayDuration: Int = 60
    @State private var spotNotes: String = ""
    @State private var transportMethod: String = "電車"
    @State private var transportDuration: Int = 30
    @State private var transportCost: Int = 0
    @State private var transportRoute: String = ""
    
    let transportMethods = ["電車", "バス", "徒歩", "タクシー"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("スポット情報") {
                    TextField("スポット名", text: $spotName)
                    TextField("最寄り駅", text: $nearestStation)
                    TextField("住所", text: $spotAddress)
                    
                    HStack {
                        Text("滞在時間")
                        Spacer()
                        Picker("", selection: $stayDuration) {
                            ForEach([30, 60, 90, 120], id: \.self) { minutes in
                                Text("\(minutes)分").tag(minutes)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                    
                    TextField("メモ", text: $spotNotes, axis: .vertical)
                        .lineLimit(2...4)
                }
                
                if !previousSpots.isEmpty {
                    Section("交通機関") {
                        Picker("移動手段", selection: $transportMethod) {
                            ForEach(transportMethods, id: \.self) { method in
                                Text(method).tag(method)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        
                        HStack {
                            Text("移動時間")
                            Spacer()
                            TextField("分", value: $transportDuration, format: .number)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 60)
                                .multilineTextAlignment(.trailing)
                            Text("分")
                        }
                        
                        HStack {
                            Text("料金")
                            Spacer()
                            TextField("円", value: $transportCost, format: .number)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 80)
                                .multilineTextAlignment(.trailing)
                            Text("円")
                        }
                        
                        TextField("経路（例：JR山手線→東京メトロ）", text: $transportRoute)
                    }
                }
            }
            .navigationTitle("スポット追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("追加") {
                        if !previousSpots.isEmpty && previousSpots.count == spots.count {
                            spots[spots.count - 1].transportToNext = TransportInfo(
                                method: transportMethod,
                                duration: transportDuration,
                                cost: transportCost,
                                route: transportRoute
                            )
                        }
                        
                        let newSpot = VisitSpot(
                            name: spotName,
                            address: spotAddress,
                            notes: spotNotes,
                            nearestStation: nearestStation,
                            stayDuration: stayDuration
                        )
                        spots.append(newSpot)
                        dismiss()
                    }
                    .disabled(spotName.isEmpty)
                }
            }
        }
    }
}

struct EditSpotView: View {
    @Environment(\.dismiss) var dismiss
    let spot: VisitSpot
    @Binding var spots: [VisitSpot]
    let startTime: Date
    
    @State private var spotName: String
    @State private var spotAddress: String
    @State private var nearestStation: String
    @State private var stayDuration: Int
    @State private var spotNotes: String
    
    init(spot: VisitSpot, spots: Binding<[VisitSpot]>, startTime: Date) {
        self.spot = spot
        self._spots = spots
        self.startTime = startTime
        self._spotName = State(initialValue: spot.name)
        self._spotAddress = State(initialValue: spot.address)
        self._nearestStation = State(initialValue: spot.nearestStation)
        self._stayDuration = State(initialValue: spot.stayDuration)
        self._spotNotes = State(initialValue: spot.notes)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("スポット情報") {
                    TextField("スポット名", text: $spotName)
                    TextField("最寄り駅", text: $nearestStation)
                    TextField("住所", text: $spotAddress)
                    
                    HStack {
                        Text("滞在時間")
                        Spacer()
                        Picker("", selection: $stayDuration) {
                            ForEach([30, 60, 90, 120], id: \.self) { minutes in
                                Text("\(minutes)分").tag(minutes)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                    
                    TextField("メモ", text: $spotNotes, axis: .vertical)
                        .lineLimit(2...4)
                }
                
                Section {
                    Button("削除", role: .destructive) {
                        if let index = spots.firstIndex(where: { $0.id == spot.id }) {
                            spots.remove(at: index)
                            if index > 0 && index < spots.count {
                                spots[index - 1].transportToNext = nil
                            }
                        }
                        dismiss()
                    }
                }
            }
            .navigationTitle("スポット編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        if let index = spots.firstIndex(where: { $0.id == spot.id }) {
                            spots[index].name = spotName
                            spots[index].address = spotAddress
                            spots[index].nearestStation = nearestStation
                            spots[index].stayDuration = stayDuration
                            spots[index].notes = spotNotes
                        }
                        dismiss()
                    }
                }
            }
        }
    }
}