import SwiftUI
import PhotosUI

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
                            // サムネイル選択
                            VStack(alignment: .leading, spacing: 8) {
                                Text("サムネイル画像")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.black)
                                    .padding(.horizontal)
                                
                                PhotosPicker(selection: $selectedImage, matching: .images) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color(.systemGray5))
                                            .frame(height: 200)
                                        
                                        if let thumbnailImage = thumbnailImage {
                                            Image(uiImage: thumbnailImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(height: 200)
                                                .clipped()
                                                .cornerRadius(12)
                                        } else {
                                            VStack(spacing: 8) {
                                                Image(systemName: "photo")
                                                    .font(.system(size: 40))
                                                    .foregroundColor(.gray)
                                                Text("タップして画像を選択")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                                .onChange(of: selectedImage) { newItem in
                                    Task {
                                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                                           let uiImage = UIImage(data: data) {
                                            thumbnailImage = uiImage
                                            thumbnailData = data
                                        }
                                    }
                                }
                            }
                            
                            // プランタイトル入力
                            VStack(alignment: .leading, spacing: 8) {
                                Text("プランタイトル")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.black)
                                TextField("例: 青春ブタ野郎 江ノ島聖地巡礼", text: $planTitle)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .font(.system(size: 16))
                            }
                            .padding(.horizontal)
                            
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
                    
                    // 保存してゲーム開始ボタン
                    Button(action: {
                        if !selectedDuration.isEmpty && !spots.isEmpty && !planTitle.isEmpty {
                            savePlan()
                            showingGame = true
                        }
                    }) {
                        Text("保存してゲーム開始")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill((!selectedDuration.isEmpty && !spots.isEmpty && !planTitle.isEmpty) ? Color.blue : Color.gray)
                            )
                    }
                    .disabled(selectedDuration.isEmpty || spots.isEmpty || planTitle.isEmpty)
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
    
    func savePlan() {
        let plan = VisitPlanData(
            animeName: animeName,
            title: planTitle,
            duration: selectedDuration,
            spots: spots,
            thumbnailData: thumbnailData
        )
        
        // UserDefaultsに保存
        if let encoded = try? JSONEncoder().encode(plan) {
            var savedPlans = getSavedPlans()
            savedPlans.append(plan)
            
            if let encodedPlans = try? JSONEncoder().encode(savedPlans) {
                UserDefaults.standard.set(encodedPlans, forKey: "visitPlans")
            }
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
    @State private var selectedEventType: EventType = .findLocation
    @State private var eventDescription = ""
    @State private var quizQuestion = ""
    @State private var quizAnswer = ""
    @State private var addEvent = false
    
    var body: some View {
        NavigationView {
            ScrollView {
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
                    
                    Divider()
                    
                    // イベント設定
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("イベントを追加", isOn: $addEvent)
                            .font(.system(size: 16, weight: .medium))
                        
                        if addEvent {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("イベントタイプ")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.gray)
                                
                                Picker("イベントタイプ", selection: $selectedEventType) {
                                    ForEach(EventType.allCases, id: \.self) { type in
                                        Text(type.rawValue).tag(type)
                                    }
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("イベント説明")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.gray)
                                    TextField("例: 古賀が振られた場所を探そう", text: $eventDescription)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                }
                                
                                if selectedEventType == .animeQuiz {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("クイズ問題")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.gray)
                                        TextField("例: この場所で古賀は何をした？", text: $quizQuestion)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                        
                                        Text("答え")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.gray)
                                        TextField("例: 告白を断られた", text: $quizAnswer)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding()
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
                    Button("追加") {
                        if !spotName.isEmpty {
                            var event: SpotEvent? = nil
                            if addEvent && !eventDescription.isEmpty {
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
                    }
                    .disabled(spotName.isEmpty)
                }
            }
        }
    }
}

// ゲーム画面
struct VisitGameScreen: View {
    @Environment(\.dismiss) var dismiss
    let animeName: String
    let duration: String
    let spots: [VisitSpot]
    @State private var currentSpotIndex: Int?
    @State private var visitedSpots: Set<UUID> = []
    @State private var showingEvent = false
    @State private var eventCompleted = false
    @State private var stamps: [UUID: Bool] = [:]
    @State private var showingComplete = false
    @State private var quizAnswer = ""
    @State private var showingPhotoCapture = false
    @State private var capturedImage: UIImage?
    
    var remainingSpots: [VisitSpot] {
        spots.filter { !visitedSpots.contains($0.id) }
    }
    
    var currentSpot: VisitSpot? {
        guard let index = currentSpotIndex, index < spots.count else { return nil }
        return spots[index]
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // ヘッダー
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    VStack(spacing: 4) {
                        Text(animeName.isEmpty ? "聖地巡礼" : animeName)
                            .font(.system(size: 16, weight: .medium))
                        Text("期間: \(duration)")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    // スタンプ数
                    VStack(spacing: 4) {
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.yellow)
                        Text("\(stamps.filter { $0.value }.count)/\(spots.count)")
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .padding()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // スタンプカード
                        VStack(spacing: 12) {
                            Text("スタンプカード")
                                .font(.system(size: 18, weight: .semibold))
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                                ForEach(spots) { spot in
                                    VStack(spacing: 4) {
                                        ZStack {
                                            Circle()
                                                .fill(stamps[spot.id] == true ? Color.yellow : Color(.systemGray5))
                                                .frame(width: 60, height: 60)
                                            
                                            if stamps[spot.id] == true {
                                                Image(systemName: "star.fill")
                                                    .font(.system(size: 30))
                                                    .foregroundColor(.white)
                                            } else {
                                                Text("\(spots.firstIndex(where: { $0.id == spot.id })! + 1)")
                                                    .font(.system(size: 20, weight: .medium))
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                        Text(spot.name)
                                            .font(.system(size: 10))
                                            .foregroundColor(.gray)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        
                        if currentSpotIndex == nil {
                            // スタート画面
                            VStack(spacing: 16) {
                                Image(systemName: "flag.checkered")
                                    .font(.system(size: 50))
                                    .foregroundColor(.green)
                                Text("聖地巡礼を始めましょう！")
                                    .font(.system(size: 20, weight: .semibold))
                                Button(action: { selectRandomSpot() }) {
                                    Text("スタート")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 60)
                                        .padding(.vertical, 16)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.green)
                                        )
                                }
                            }
                            .padding(.top, 40)
                        } else if let spot = currentSpot {
                            // 現在のスポット情報
                            VStack(spacing: 16) {
                                Text("現在の目的地")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.gray)
                                
                                VStack(spacing: 8) {
                                    Text(spot.name)
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundColor(.blue)
                                    
                                    if !spot.address.isEmpty {
                                        Text(spot.address)
                                            .font(.system(size: 16))
                                            .foregroundColor(.gray)
                                    }
                                    
                                    if !spot.notes.isEmpty {
                                        Text(spot.notes)
                                            .font(.system(size: 14))
                                            .foregroundColor(.gray)
                                            .padding(.top, 4)
                                    }
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                
                                Button(action: { showingEvent = true }) {
                                    HStack {
                                        Image(systemName: "location.fill")
                                        Text("到着しました")
                                    }
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 40)
                                    .padding(.vertical, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.blue)
                                    )
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 20)
                        }
                        
                        if visitedSpots.count == spots.count {
                            // 完了画面
                            VStack(spacing: 16) {
                                Image(systemName: "trophy.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.yellow)
                                Text("聖地巡礼コンプリート！")
                                    .font(.system(size: 24, weight: .bold))
                                Text("おめでとうございます！")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                            }
                            .padding(.top, 40)
                        }
                    }
                }
            }
            
            // イベントモーダル
            if showingEvent, let spot = currentSpot, let event = spot.event {
                EventModalView(
                    event: event,
                    onComplete: {
                        stamps[spot.id] = true
                        visitedSpots.insert(spot.id)
                        showingEvent = false
                        if visitedSpots.count < spots.count {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                selectRandomSpot()
                            }
                        }
                    },
                    quizAnswer: $quizAnswer,
                    showingPhotoCapture: $showingPhotoCapture,
                    capturedImage: $capturedImage
                )
            }
        }
        .sheet(isPresented: $showingPhotoCapture) {
            ImagePicker(image: $capturedImage)
        }
    }
    
    func selectRandomSpot() {
        if let randomSpot = remainingSpots.randomElement(),
           let index = spots.firstIndex(where: { $0.id == randomSpot.id }) {
            currentSpotIndex = index
        }
    }
}

struct EventModalView: View {
    let event: SpotEvent
    let onComplete: () -> Void
    @Binding var quizAnswer: String
    @Binding var showingPhotoCapture: Bool
    @Binding var capturedImage: UIImage?
    @State private var showingResult = false
    @State private var isCorrect = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("イベント")
                    .font(.system(size: 24, weight: .bold))
                
                Text(event.description)
                    .font(.system(size: 18))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                switch event.type {
                case .findLocation, .animeScene:
                    VStack(spacing: 16) {
                        Image(systemName: "location.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        Text("この場所に到着しました！")
                            .font(.system(size: 16))
                        Button(action: onComplete) {
                            Text("スタンプをもらう")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 40)
                                .padding(.vertical, 16)
                                .background(Color.green)
                                .cornerRadius(12)
                        }
                    }
                    
                case .takePhoto:
                    VStack(spacing: 16) {
                        if let image = capturedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .cornerRadius(12)
                            Text("写真を撮影しました！")
                                .font(.system(size: 16))
                            Button(action: onComplete) {
                                Text("スタンプをもらう")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 40)
                                    .padding(.vertical, 16)
                                    .background(Color.green)
                                    .cornerRadius(12)
                            }
                        } else {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)
                            Button(action: { showingPhotoCapture = true }) {
                                Text("写真を撮る")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 40)
                                    .padding(.vertical, 16)
                                    .background(Color.blue)
                                    .cornerRadius(12)
                            }
                        }
                    }
                    
                case .animeQuiz:
                    if !showingResult {
                        VStack(spacing: 16) {
                            Text(event.question)
                                .font(.system(size: 16))
                                .multilineTextAlignment(.center)
                            TextField("答えを入力", text: $quizAnswer)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.horizontal)
                            Button(action: {
                                isCorrect = quizAnswer.lowercased().contains(event.answer.lowercased())
                                showingResult = true
                            }) {
                                Text("回答する")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 40)
                                    .padding(.vertical, 16)
                                    .background(Color.blue)
                                    .cornerRadius(12)
                            }
                        }
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(isCorrect ? .green : .red)
                            Text(isCorrect ? "正解！" : "不正解...")
                                .font(.system(size: 24, weight: .bold))
                            if !isCorrect {
                                Text("正解: \(event.answer)")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                            }
                            Button(action: onComplete) {
                                Text("スタンプをもらう")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 40)
                                    .padding(.vertical, 16)
                                    .background(Color.green)
                                    .cornerRadius(12)
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(20)
            .padding(.horizontal, 30)
        }
    }
}

// カメラ機能用
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
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
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}