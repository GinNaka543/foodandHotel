import SwiftUI
import PhotosUI

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

struct VisitPlanningScreen: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedDuration: String = ""
    @State private var spots: [VisitSpot] = []
    @State private var showingAddSpotSheet = false
    @State private var animeName: String = ""
    @State private var planTitle: String = ""
    @State private var showingGame = false
    @State private var selectedImage: PhotosPickerItem?
    @State private var thumbnailImage: UIImage?
    @State private var thumbnailData: Data?
    
    let durations = ["半日", "1日", "3日"]
    
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
                        // タイトル入力
                        VStack(alignment: .leading, spacing: 8) {
                            Text("プランタイトル")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                            TextField("例: 京都の聖地巡礼", text: $planTitle)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.system(size: 16))
                        }
                        .padding(.horizontal, 16)
                        
                        // アニメ名入力
                        VStack(alignment: .leading, spacing: 8) {
                            Text("アニメ名")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                            TextField("例: 響け！ユーフォニアム", text: $animeName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.system(size: 16))
                        }
                        .padding(.horizontal, 16)
                        
                        // サムネイル選択
                        VStack(alignment: .leading, spacing: 8) {
                            Text("サムネイル画像")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                            
                            PhotosPicker(selection: $selectedImage,
                                       matching: .images,
                                       photoLibrary: .shared()) {
                                if let thumbnailImage = thumbnailImage {
                                    Image(uiImage: thumbnailImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 200)
                                        .clipped()
                                        .cornerRadius(12)
                                } else {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.systemGray5))
                                        .frame(height: 200)
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
                            .onChange(of: selectedImage) { newItem in
                                Task {
                                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                        thumbnailImage = UIImage(data: data)
                                        thumbnailData = data
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        // 期間選択
                        VStack(alignment: .leading, spacing: 8) {
                            Text("期間")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                            
                            HStack(spacing: 12) {
                                ForEach(durations, id: \.self) { duration in
                                    Button(action: { selectedDuration = duration }) {
                                        Text(duration)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(selectedDuration == duration ? .white : .blue)
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 10)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(selectedDuration == duration ? Color.blue : Color.blue.opacity(0.1))
                                            )
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        // スポット一覧
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("スポット一覧")
                                    .font(.system(size: 18, weight: .semibold))
                                Spacer()
                                Button(action: { showingAddSpotSheet = true }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal, 16)
                            
                            if spots.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "mappin.slash")
                                        .font(.system(size: 40))
                                        .foregroundColor(.gray)
                                    Text("スポットがまだ追加されていません")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                            } else {
                                ForEach(spots) { spot in
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Image(systemName: "mappin.circle.fill")
                                                .font(.system(size: 20))
                                                .foregroundColor(.red)
                                            Text(spot.name)
                                                .font(.system(size: 16, weight: .medium))
                                            Spacer()
                                            if let event = spot.event {
                                                Text(event.type.rawValue)
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(
                                                        Capsule()
                                                            .fill(Color.blue)
                                                    )
                                            }
                                        }
                                        if !spot.address.isEmpty {
                                            Text(spot.address)
                                                .font(.system(size: 14))
                                                .foregroundColor(.gray)
                                                .padding(.leading, 28)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color(.systemGray6))
                                    )
                                    .padding(.horizontal, 16)
                                }
                            }
                        }
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.top, 16)
                }
                
                // 下部のボタン
                HStack(spacing: 16) {
                    Button(action: {
                        // プランを保存
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
                    .disabled(planTitle.isEmpty || animeName.isEmpty || selectedDuration.isEmpty)
                    
                    Button(action: {
                        showingGame = true
                    }) {
                        Text("ゲーム開始")
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
            AddSpotView(spots: $spots)
        }
        .fullScreenCover(isPresented: $showingGame) {
            VisitGameScreen(
                animeName: animeName,
                duration: selectedDuration,
                spots: spots
            )
        }
    }
    
    func savePlan() {
        let plan = VisitPlanData(
            animeName: animeName,
            title: planTitle,
            duration: selectedDuration,
            spots: spots,
            thumbnailData: thumbnailData
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

struct AddSpotView: View {
    @Environment(\.dismiss) var dismiss
    let spot: VisitSpot
    @State private var spotName: String = ""
    @State private var spotAddress: String = ""
    @State private var spotNotes: String = ""
    @State private var hasEvent: Bool = false
    @State private var eventDescription: String = ""
    @State private var quizQuestion: String = ""
    @State private var quizAnswer: String = ""
    @Binding var spots: [VisitSpot]
    
    // 新しいスポット追加用のイニシャライザ
    init(spots: Binding<[VisitSpot]>) {
        self.spot = VisitSpot(name: "", address: "", notes: "")
        self._spots = spots
        self._selectedEventType = State(initialValue: .findLocation)
    }
    
    // 既存スポット編集用のイニシャライザ
    init(spot: VisitSpot, spots: Binding<[VisitSpot]>) {
        self.spot = spot
        self._spots = spots
        self._spotName = State(initialValue: spot.name)
        self._spotAddress = State(initialValue: spot.address)
        self._spotNotes = State(initialValue: spot.notes)
        self._hasEvent = State(initialValue: spot.event != nil)
        if let event = spot.event {
            self._selectedEventType = State(initialValue: event.type)
            self._eventDescription = State(initialValue: event.description)
            self._quizQuestion = State(initialValue: event.question)
            self._quizAnswer = State(initialValue: event.answer)
        } else {
            self._selectedEventType = State(initialValue: .findLocation)
        }
    }
    
    @State private var selectedEventType: EventType = .findLocation
    
    var body: some View {
        NavigationView {
            Form {
                Section("スポット情報") {
                    TextField("スポット名", text: $spotName)
                    TextField("住所", text: $spotAddress)
                    TextField("メモ", text: $spotNotes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section {
                    Toggle("イベントを設定", isOn: $hasEvent)
                    
                    if hasEvent {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("イベントタイプ", selection: $selectedEventType) {
                                ForEach(EventType.allCases, id: \.self) { type in
                                    Text(type.rawValue).tag(type)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            
                            TextField("イベント説明", text: $eventDescription, axis: .vertical)
                                .lineLimit(2...4)
                            
                            if selectedEventType == .animeQuiz {
                                TextField("クイズ問題", text: $quizQuestion, axis: .vertical)
                                    .lineLimit(2...4)
                                TextField("答え", text: $quizAnswer)
                            }
                        }
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
                        var event: SpotEvent? = nil
                        if hasEvent {
                            event = SpotEvent(
                                type: selectedEventType,
                                description: eventDescription,
                                question: quizQuestion,
                                answer: quizAnswer
                            )
                        }
                        
                        let newSpot = VisitSpot(
                            name: spotName,
                            address: spotAddress,
                            notes: spotNotes,
                            event: event
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

// Event detail for showing event information
struct EventDetailView: View {
    let event: SpotEvent
    @Binding var userAnswer: String
    @State private var showingResult = false
    @State private var isCorrect = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: iconForEventType(event.type))
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                
                Text(event.type.rawValue)
                    .font(.system(size: 18, weight: .semibold))
            }
            
            Text(event.description)
                .font(.system(size: 16))
                .foregroundColor(.gray)
            
            if event.type == .animeQuiz && !event.question.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("クイズ:")
                        .font(.system(size: 16, weight: .semibold))
                    
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
            }
        }
        .padding()
        .alert(isPresented: $showingResult) {
            Alert(
                title: Text(isCorrect ? "正解！" : "不正解"),
                message: Text(isCorrect ? "素晴らしい！" : "正解は: \(event.answer)"),
                dismissButton: .default(Text("OK"))
            )
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