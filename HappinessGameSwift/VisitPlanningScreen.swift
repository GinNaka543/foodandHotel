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
    @State private var numberOfDays: Int = 1
    @State private var selectedDay: Int = 1
    @State private var showingDayPicker = false
    @State private var selectedDayForNewSpot: Int = 1
    @State private var showingCustomDaysPicker = false
    @State private var customDaysInput: String = ""
    @State private var planDescription: String = ""
    @State private var planPrice: Int = 0
    @State private var planBudget: Int = 0
    @State private var isPublic: Bool = false
    @State private var showingConfirmation = false
    @State private var showingPointPurchase = false
    @State private var showingPaymentSheet = false
    @State private var showingPublishDialog = false
    @StateObject private var firebaseManager = FirebaseManager.shared
    @StateObject private var stripeManager = StripePaymentManager.shared
    @StateObject private var githubManager = GitHubImageManager.shared
    
    // 編集中の下書きデータ
    private let editingDraftId: UUID?
    
    init(editingDraft: VisitPlanData? = nil) {
        if let draft = editingDraft {
            // print("DEBUG: 下書きデータを読み込み中: \(draft.title)")
            self.editingDraftId = draft.id
            self._animeName = State(initialValue: draft.animeName)
            self._planTitle = State(initialValue: draft.title)
            self._spots = State(initialValue: draft.spots)
            self._thumbnailData = State(initialValue: draft.thumbnailData)
            self._startTime = State(initialValue: draft.startTime)
            self._numberOfDays = State(initialValue: draft.numberOfDays)
            if let thumbnailData = draft.thumbnailData {
                self._thumbnailImage = State(initialValue: UIImage(data: thumbnailData))
            }
        } else {
            self.editingDraftId = nil
        }
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
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ヘッダー
                HStack {
                    Button(action: { 
                        // 戻るボタンを押した時、未確定のプランを自動的に下書き保存
                        if !planTitle.isEmpty || !animeName.isEmpty || !spots.isEmpty {
                            saveDraftSilently()
                        } else {
                            dismiss()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20, weight: .medium))
                            Text(NSLocalizedString("back", comment: "Back"))
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
                                HStack {
                                    Text(NSLocalizedString("plan_title", comment: "Plan title"))
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.gray)
                                    Text(NSLocalizedString("required", comment: "Required"))
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.red)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.red.opacity(0.1))
                                        .cornerRadius(4)
                                }
                                TextField(NSLocalizedString("plan_title_placeholder", comment: "e.g. Kyoto pilgrimage"), text: $planTitle)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .font(.system(size: 16))
                            }
                            
                            // アニメ名入力
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(NSLocalizedString("anime_name", comment: "Anime name"))
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.gray)
                                    Text(NSLocalizedString("required", comment: "Required"))
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.red)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.red.opacity(0.1))
                                        .cornerRadius(4)
                                }
                                TextField(NSLocalizedString("anime_name_placeholder", comment: "e.g. Sound! Euphonium"), text: $animeName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .font(.system(size: 16))
                            }
                            
                            // 開始時刻と旅行日数
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(NSLocalizedString("start_time", comment: "Start time"))
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.gray)
                                    DatePicker("", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                                        .datePickerStyle(CompactDatePickerStyle())
                                        .labelsHidden()
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(NSLocalizedString("trip_days", comment: "Number of days"))
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.gray)
                                    
                                    if numberOfDays <= 7 {
                                        Menu {
                                            ForEach(1...7, id: \.self) { days in
                                                Button(String(format: NSLocalizedString("days_format", comment: "%d days"), days)) {
                                                    numberOfDays = days
                                                }
                                            }
                                            Divider()
                                            Button(NSLocalizedString("customize", comment: "Customize")) {
                                                showingCustomDaysPicker = true
                                            }
                                        } label: {
                                            HStack {
                                                Text(String(format: NSLocalizedString("days_format", comment: "%d days"), numberOfDays))
                                                    .foregroundColor(.black)
                                                Spacer()
                                                Image(systemName: "chevron.down")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.gray)
                                            }
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 36) // DatePickerと同じ高さに
                                            .padding(.horizontal, 12)
                                            .background(Color(.systemGray6))
                                            .cornerRadius(8)
                                        }
                                    } else {
                                        Menu {
                                            ForEach(1...7, id: \.self) { days in
                                                Button(String(format: NSLocalizedString("days_format", comment: "%d days"), days)) {
                                                    numberOfDays = days
                                                }
                                            }
                                            Divider()
                                            Button(NSLocalizedString("customize", comment: "Customize")) {
                                                showingCustomDaysPicker = true
                                            }
                                        } label: {
                                            HStack {
                                                Text(String(format: NSLocalizedString("days_format", comment: "%d days"), numberOfDays))
                                                    .foregroundColor(.black)
                                                Spacer()
                                                Image(systemName: "chevron.down")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.gray)
                                            }
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 36) // DatePickerと同じ高さに
                                            .padding(.horizontal, 12)
                                            .background(Color(.systemGray6))
                                            .cornerRadius(8)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        // サムネイル選択
                        VStack(alignment: .leading, spacing: 8) {
                            Text(NSLocalizedString("thumbnail_image", comment: "Thumbnail image"))
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
                                                Text(NSLocalizedString("select_image", comment: "Select image"))
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.gray)
                                            }
                                        )
                                }
                            }
                            .padding(.horizontal, 16)
                            .onChange(of: selectedImage) { _, newItem in
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
                                Text(NSLocalizedString("timeline", comment: "Timeline"))
                                    .font(.system(size: 18, weight: .semibold))
                                Spacer()
                                Button(action: { 
                                    if numberOfDays > 1 {
                                        showingDayPicker = true
                                    } else {
                                        selectedDayForNewSpot = 1
                                        showingAddSpotSheet = true
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus")
                                        Text(NSLocalizedString("add", comment: "Add"))
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
                            
                            // 日数が2日以上の場合はタブ表示
                            if numberOfDays > 1 {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(1...min(numberOfDays, 30), id: \.self) { day in
                                            Button(action: { selectedDay = day }) {
                                                Text(String(format: NSLocalizedString("day_format", comment: "Day %d"), day))
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
                                }
                            }
                            
                            if spots.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.system(size: 40))
                                        .foregroundColor(.gray)
                                    Text(NSLocalizedString("add_spots_to_create_itinerary", comment: "Add spots to create itinerary"))
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                            } else {
                                let filteredSpots = spots.filter { $0.dayNumber == selectedDay }
                                VStack(spacing: 0) {
                                    ForEach(Array(filteredSpots.enumerated()), id: \.element.id) { index, spot in
                                        TimelineItem(
                                            spot: spot,
                                            index: index,
                                            totalSpots: filteredSpots.count,
                                            startTime: startTime,
                                            previousSpots: Array(filteredSpots.prefix(index))
                                        )
                                        .onTapGesture {
                                            editingSpot = spot
                                        }
                                        
                                        if index < filteredSpots.count - 1 {
                                            TransportView(
                                                from: spot,
                                                to: filteredSpots[index + 1]
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
                                    Text(NSLocalizedString("overview", comment: "Overview"))
                                        .font(.system(size: 16, weight: .semibold))
                                    Spacer()
                                }
                                HStack {
                                    Label("予想費用", systemImage: "yensign.circle")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Text(String(format: NSLocalizedString("price_format", comment: "¥%d"), calculateTotalCost()))
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
                VStack(spacing: 12) {
                    Button(action: {
                        showingItinerary = true
                    }) {
                        Text(NSLocalizedString("review_itinerary", comment: "Review itinerary"))
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.black)
                            )
                    }
                    .disabled(spots.isEmpty)
                    
                    HStack(spacing: 16) {
                        Button(action: {
                            saveDraft()
                        }) {
                            Text(NSLocalizedString("save_draft", comment: "Save draft"))
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.blue, lineWidth: 2)
                                )
                        }
                        
                        Button(action: {
                            showingConfirmation = true
                        }) {
                            Text(NSLocalizedString("finalize_plan", comment: "Finalize plan"))
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.red)
                                )
                        }
                        .disabled(planTitle.isEmpty || animeName.isEmpty || spots.isEmpty)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingConfirmation) {
            PlanConfirmationView(
                planTitle: planTitle,
                onConfirm: { 
                    confirmPlanWithPoints()
                },
                onCancel: { 
                    showingConfirmation = false 
                },
                onPurchasePoints: {
                    showingConfirmation = false
                    showingPointPurchase = true
                }
            )
        }
        .sheet(isPresented: $showingPointPurchase) {
            PointPurchaseView(onPurchaseComplete: {
                showingPointPurchase = false
            })
        }
        .sheet(isPresented: $showingPublishDialog) {
            PublishPlanDialog(
                planTitle: planTitle,
                planDescription: $planDescription,
                planPrice: $planPrice,
                planBudget: $planBudget,
                onPublish: { publishPlan() },
                onCancel: { showingPublishDialog = false }
            )
        }
        .sheet(isPresented: $showingAddSpotSheet) {
            AddSpotView(spots: $spots, startTime: startTime, previousSpots: spots, selectedDay: selectedDayForNewSpot)
        }
        .sheet(isPresented: $showingDayPicker) {
            DayPickerView(numberOfDays: numberOfDays, selectedDay: $selectedDayForNewSpot) {
                showingDayPicker = false
                showingAddSpotSheet = true
            }
        }
        .sheet(item: $editingSpot) { spot in
            EditSpotView(spot: spot, spots: $spots, startTime: startTime)
        }
        .sheet(isPresented: $showingCustomDaysPicker) {
            CustomDaysPickerView(numberOfDays: $numberOfDays)
        }
        .fullScreenCover(isPresented: $showingItinerary) {
            VisitGameScreen(
                animeName: animeName,
                duration: formatTotalDuration(),
                planTitle: planTitle,
                spots: updateSpotTimes(),
                numberOfDays: numberOfDays,
                startTime: startTime,
                onClose: {
                    showingItinerary = false
                },
                isReadOnly: true,  // 読み取り専用モード
                thumbnailUrl: nil
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
            total + spot.spotCost + (spot.transportToNext?.cost ?? 0)
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
            startTime: startTime,
            numberOfDays: numberOfDays
        )
        
        var savedPlans = getSavedPlans()
        savedPlans.append(plan)
        
        if let encoded = try? JSONEncoder().encode(savedPlans) {
            UserDefaultsHelper.shared.setData(encoded, forKey: "savedPlans")
        }
    }
    
    func getSavedPlans() -> [VisitPlanData] {
        guard let data = UserDefaultsHelper.shared.getData(forKey: "savedPlans"),
              let plans = try? JSONDecoder().decode([VisitPlanData].self, from: data) else {
            return []
        }
        return plans
    }
    
    func savePlanPrivately() {
        // プライベートプランとして保存（支払い不要）
        uploadPlanToFirebase(payment: nil, isPublic: false)
    }
    
    func publishPlan() {
        // 予算チェック
        guard planBudget > 0 else {
            // エラー表示
            return
        }
        
        // 支払い処理を開始
        // let userId = UserDefaults.standard.string(forKey: "userId") ?? UUID().uuidString
        
        // TODO: payForPlanPosting メソッドが見つからないため、一時的にコメントアウト
        // 支払い処理なしで公開
        self.uploadPlanToFirebase(payment: nil, isPublic: true)
        
        /* stripeManager.payForPlanPosting(userId: userId) { result in
            switch result {
            case .success(let payment):
                // 支払い成功後、プランをFirebaseに保存
                self.uploadPlanToFirebase(payment: payment, isPublic: true)
            case .failure(_):
                break
            }
        } */
    }
    
    func uploadPlanToFirebase(payment: PlanPostingPayment?, isPublic: Bool) {
        let userId = UserDefaults.standard.string(forKey: "userId") ?? UUID().uuidString
        
        // 画像をGitHubにアップロード
        var thumbnailUrl: String?
        let group = DispatchGroup()
        
        if let thumbnailImage = thumbnailImage {
            group.enter()
            githubManager.uploadImage(thumbnailImage, fileName: "plan_\(UUID().uuidString)") { result in
                switch result {
                case .success(let url):
                    thumbnailUrl = url
                case .failure(_):
                    break
                }
                group.leave()
            }
        }
        
        group.notify(queue: DispatchQueue.main, execute: {
            // Firebaseにプランを保存
            let plan = VisitPlanModel(
                id: UUID().uuidString,
                userId: userId,
                animeName: self.animeName,
                title: self.planTitle,
                description: self.planDescription,
                duration: self.formatTotalDuration(),
                spots: self.updateSpotTimes(),
                thumbnailUrl: thumbnailUrl,
                price: self.planPrice,
                budget: self.planBudget,
                createdDate: Date(),
                startTime: self.startTime,
                numberOfDays: self.numberOfDays,
                totalCost: self.calculateTotalCost(),
                isPublic: isPublic,
                purchasedBy: [],
                createdAt: Date(),
                updatedAt: Date()
            )
            
            self.firebaseManager.saveVisitPlan(plan) { result in
                switch result {
                case .success:
                    if let payment = payment {
                        // 支払い記録を保存（パブリックプランの場合のみ）
                        self.firebaseManager.recordPlanPostingPayment(payment) { _ in
                            DispatchQueue.main.async {
                                self.dismiss()
                            }
                        }
                    } else {
                        // プライベートプランの場合はそのまま閉じる
                        DispatchQueue.main.async {
                            self.dismiss()
                        }
                    }
                case .failure(_):
                    break
                }
            }
        })
    }
    
    func confirmPlanWithPoints() {
        showingConfirmation = false
        
        let userId = UserDefaults.standard.string(forKey: "userId") ?? UUID().uuidString
        
        // 50ポイントを消費してプランを確定
        firebaseManager.usePoints(userId: userId, points: 50, reason: "プラン確定") { result in
            switch result {
            case .success:
                // ポイント消費成功、プランを保存
                self.savePlanAsConfirmed()
            case .failure(_):
                // エラー処理（必要に応じてアラートを表示）
                break
            }
        }
    }
    
    func savePlanAsConfirmed() {
        let userId = UserDefaults.standard.string(forKey: "userId") ?? UUID().uuidString
        
        // ローカルに保存するためのプランデータを作成
        let planData = VisitPlanData(
            animeName: animeName,
            title: planTitle.isEmpty ? "無題のプラン" : planTitle,
            duration: formatTotalDuration(),
            spots: updateSpotTimes(),
            thumbnailData: thumbnailData,
            startTime: startTime,
            numberOfDays: numberOfDays,
            isPurchased: false,
            isDraft: false
        )
        
        // ローカルストレージに保存
        var savedPlans = getSavedPlans()
        savedPlans.append(planData)
        
        if let encoded = try? JSONEncoder().encode(savedPlans) {
            UserDefaultsHelper.shared.setData(encoded, forKey: "savedPlans")
        }
        
        // Firebaseにも保存
        let plan = VisitPlanModel(
            id: planData.id.uuidString,
            userId: userId,
            animeName: animeName,
            title: planTitle.isEmpty ? "無題のプラン" : planTitle,
            description: "",
            duration: formatTotalDuration(),
            spots: updateSpotTimes(),
            thumbnailUrl: nil,
            price: 0,
            budget: calculateTotalCost(),
            createdDate: Date(),
            startTime: startTime,
            numberOfDays: numberOfDays,
            totalCost: calculateTotalCost(),
            isPublic: false, // プライベートプランとして保存
            purchasedBy: [],
            createdAt: Date(),
            updatedAt: Date(),
            isDraft: false,
            isConfirmed: true // 確定済みフラグ
        )
        
        // ローカルに保存
        var localPlans = getSavedPlans()
        localPlans.append(planData)
        
        if let encoded = try? JSONEncoder().encode(localPlans) {
            UserDefaultsHelper.shared.setData(encoded, forKey: "savedPlans")
        }
        
        // Firebaseに保存
        firebaseManager.saveVisitPlan(plan) { result in
            switch result {
            case .success:
                DispatchQueue.main.async {
                    // オリジナルタブに遷移
                    NotificationCenter.default.post(
                        name: Notification.Name("NavigateToVisitOriginalTab"),
                        object: nil
                    )
                    self.dismiss()
                }
            case .failure(_):
                break
            }
        }
    }
    
    func saveDraft() {
        // 下書きプランデータを作成
        let planData = VisitPlanData(
            id: editingDraftId ?? UUID(), // 編集中の場合は既存のIDを使用
            animeName: animeName,
            title: planTitle.isEmpty ? "無題のプラン" : planTitle,
            duration: formatTotalDuration(),
            spots: updateSpotTimes(),
            thumbnailData: thumbnailData,
            startTime: startTime,
            numberOfDays: numberOfDays,
            isPurchased: false,
            isDraft: true
        )
        
        var savedPlans = getSavedPlans()
        
        if let editingId = editingDraftId {
            // 既存の下書きを更新
            if let index = savedPlans.firstIndex(where: { $0.id == editingId }) {
                savedPlans[index] = planData
            } else {
                // 既存の下書きが見つからない場合は新規追加
                savedPlans.append(planData)
            }
        } else {
            // 新規の下書きとして追加
            savedPlans.append(planData)
        }
        
        if let encoded = try? JSONEncoder().encode(savedPlans) {
            UserDefaultsHelper.shared.setData(encoded, forKey: "savedPlans")
            
            DispatchQueue.main.async {
                // オリジナルタブに遷移
                NotificationCenter.default.post(
                    name: Notification.Name("NavigateToVisitOriginalTab"),
                    object: nil
                )
                self.dismiss()
            }
        } else {
        }
    }
    
    func saveDraftSilently() {
        // 下書きプランデータを作成
        let planData = VisitPlanData(
            id: editingDraftId ?? UUID(), // 編集中の場合は既存のIDを使用
            animeName: animeName,
            title: planTitle.isEmpty ? "無題のプラン" : planTitle,
            duration: formatTotalDuration(),
            spots: updateSpotTimes(),
            thumbnailData: thumbnailData,
            startTime: startTime,
            numberOfDays: numberOfDays,
            isPurchased: false,
            isDraft: true
        )
        
        var savedPlans = getSavedPlans()
        
        if let editingId = editingDraftId {
            // 既存の下書きを更新
            if let index = savedPlans.firstIndex(where: { $0.id == editingId }) {
                savedPlans[index] = planData
            } else {
                // 既存の下書きが見つからない場合は新規追加
                savedPlans.append(planData)
            }
        } else {
            // 新規の下書きとして追加
            savedPlans.append(planData)
        }
        
        if let encoded = try? JSONEncoder().encode(savedPlans) {
            UserDefaultsHelper.shared.setData(encoded, forKey: "savedPlans")
        } else {
        }
        
        // dismiss()を最後に呼び出す
        DispatchQueue.main.async {
            self.dismiss()
        }
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

struct CustomDaysPickerView: View {
    @Binding var numberOfDays: Int
    @State private var selectedDays: Int = 8
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("旅行日数を入力")
                    .font(.system(size: 18, weight: .semibold))
                    .padding(.top, 20)
                
                HStack {
                    TextField("8", value: $selectedDays, format: .number)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 100)
                        .multilineTextAlignment(.center)
                        .keyboardType(.numberPad)
                    
                    Text(NSLocalizedString("days_unit", comment: "days"))
                        .font(.system(size: 16))
                }
                
                Text("1〜30日間で設定できます")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                
                Spacer()
                
                Button(action: {
                    if selectedDays >= 1 && selectedDays <= 30 {
                        numberOfDays = selectedDays
                        dismiss()
                    }
                }) {
                    Text("決定")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedDays >= 1 && selectedDays <= 30 ? Color.blue : Color.gray)
                        )
                }
                .disabled(selectedDays < 1 || selectedDays > 30)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("カスタム日数")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct DayPickerView: View {
    let numberOfDays: Int
    @Binding var selectedDay: Int
    let onSelect: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("スポットを追加する日を選択")
                    .font(.system(size: 18, weight: .semibold))
                    .padding(.top, 20)
                
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(1...min(numberOfDays, 30), id: \.self) { day in
                            Button(action: {
                                selectedDay = day
                                dismiss()
                                onSelect()
                            }) {
                                HStack {
                                    Text("Day \(day)")
                                        .font(.system(size: 16, weight: .medium))
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .navigationTitle("日付を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct AddSpotView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var spots: [VisitSpot]
    let startTime: Date
    let previousSpots: [VisitSpot]
    let selectedDay: Int
    
    @State private var spotName: String = ""
    @State private var timeRange: String = ""
    @State private var startTimeForSpot: Date
    @State private var endTimeForSpot: Date
    @State private var activity: String = ""
    @State private var spotNotes: String = ""
    @State private var spotAddress: String = ""
    @State private var spotCost: Int = 0
    @State private var selectedImages: [PhotosPickerItem] = []
    @State private var spotImages: [UIImage] = []
    @State private var spotImagesData: [Data] = []
    @State private var transportMethod: String = "電車"
    @State private var transportDuration: Int = 30
    @State private var transportCost: Int = 0
    @State private var transportRoute: String = ""
    @State private var selectedThumbnail: PhotosPickerItem?
    @State private var thumbnailImage: UIImage?
    @State private var thumbnailData: Data?
    
    let transportMethods = ["電車", "バス", "徒歩", "タクシー"]
    
    init(spots: Binding<[VisitSpot]>, startTime: Date, previousSpots: [VisitSpot], selectedDay: Int) {
        self._spots = spots
        self.startTime = startTime
        self.previousSpots = previousSpots
        self.selectedDay = selectedDay
        
        // 初期時刻を設定（現在時刻から最も近い30分単位に丸める）
        let calendar = Calendar.current
        let now = Date()
        let minute = calendar.component(.minute, from: now)
        let roundedMinute = (minute / 30) * 30
        let baseTime = calendar.date(bySettingHour: calendar.component(.hour, from: now), 
                                    minute: roundedMinute, 
                                    second: 0, 
                                    of: now) ?? now
        
        self._startTimeForSpot = State(initialValue: baseTime)
        self._endTimeForSpot = State(initialValue: calendar.date(byAdding: .hour, value: 1, to: baseTime) ?? baseTime)
    }
    
    var calculatedStayDuration: Int {
        calculateDurationFromDates(start: startTimeForSpot, end: endTimeForSpot)
    }
    
    var formattedTimeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: startTimeForSpot))〜\(formatter.string(from: endTimeForSpot))"
    }
    
    var previousSpotEndTime: String? {
        let daySpots = previousSpots.filter { $0.dayNumber == selectedDay }
        guard let lastSpot = daySpots.last else { return nil }
        
        // timeRangeから終了時刻を抽出
        let normalizedTimeRange = lastSpot.timeRange.replacingOccurrences(of: "〜", with: "~")
        let components = normalizedTimeRange.split(separator: "~")
        if components.count == 2 {
            let endTime = String(components[1])
            return endTime.trimmingCharacters(in: .whitespaces)
        }
        return nil
    }
    
    var previousSpotEndTimeSection: some View {
        Group {
            if let endTime = previousSpotEndTime {
                Section {
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.blue)
                        Text("前のスポットの終了時刻: \(endTime)")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }
    
    @ViewBuilder
    var transportSection: some View {
        if !previousSpots.isEmpty {
            let lastSpot = previousSpots.filter { $0.dayNumber == selectedDay }.last ?? previousSpots.last
            Section("移動手段 - \(lastSpot?.name ?? "前のスポット")から") {
                Picker("移動手段", selection: $transportMethod) {
                    ForEach(transportMethods, id: \.self) { method in
                        Text(method).tag(method)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("how_long_does_it_take", comment: "How long does it take?"))
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                    HStack {
                        TextField("30", value: $transportDuration, format: .number)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 60)
                            .multilineTextAlignment(.center)
                        Text(NSLocalizedString("minutes", comment: "minutes"))
                            .font(.system(size: 14))
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("transportation_cost", comment: "How much is the transportation cost?"))
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                    HStack {
                        TextField("0", value: $transportCost, format: .number)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 80)
                            .multilineTextAlignment(.center)
                        Text(NSLocalizedString("yen", comment: "yen"))
                            .font(.system(size: 14))
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("which_route_optional", comment: "Which route will you use? (Optional)"))
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                    TextField("例：JR山手線 → 東京メトロ銀座線", text: $transportRoute)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
        }
    }
    
    @ViewBuilder
    var durationText: some View {
        let duration = calculateDurationFromDates(start: startTimeForSpot, end: endTimeForSpot)
        if duration > 0 {
            Text(String(format: NSLocalizedString("stay_duration_format", comment: "Stay duration: %d minutes"), duration))
                .font(.system(size: 12))
                .foregroundColor(.blue)
        }
    }
    
    var body: some View {
        NavigationView {
            formContent
                .navigationTitle("スポット追加")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(
                    leading: Button("キャンセル") {
                        dismiss()
                    },
                    trailing: Button("追加") {
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
                            stayDuration: calculatedStayDuration,
                            transportToNext: TransportInfo(
                                method: transportMethod,
                                duration: transportDuration,
                                cost: transportCost,
                                route: transportRoute
                            ),
                            timeRange: formattedTimeRange,
                            activity: activity,
                            imageData: thumbnailData, // サムネイル画像を設定
                            detailImagesData: spotImagesData.isEmpty ? nil : spotImagesData,
                            dayNumber: selectedDay,
                            spotCost: spotCost
                        )
                        spots.append(newSpot)
                        dismiss()
                    }
                    .disabled(spotName.isEmpty || thumbnailData == nil)
                )
        }
    }
    
    var formContent: some View {
        Form {
            // 前のスポットの終了時刻を表示
            previousSpotEndTimeSection
            
            // 交通手段セクションを上に配置
            transportSection
                
                Section("スポット情報 - Day \(selectedDay)") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(NSLocalizedString("spot_name", comment: "Spot name"))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                            Text("必須")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.red)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(4)
                        }
                        TextField("例: 清水寺", text: $spotName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // 滞在時間帯選択
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("stay_time_period", comment: "Stay time period"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                        
                        HStack {
                            DatePicker("", selection: $startTimeForSpot, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .frame(width: 100)
                            
                            Text(NSLocalizedString("time_separator", comment: "~"))
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                            
                            DatePicker("", selection: $endTimeForSpot, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .frame(width: 100)
                        }
                        
                        // 計算された滞在時間を表示
                        durationText
                    }
                    
                    TextField("住所", text: $spotAddress)
                    
                    TextField("ここで何をするのか", text: $activity, axis: .vertical)
                        .lineLimit(2...4)
                    
                    TextField("メモ", text: $spotNotes, axis: .vertical)
                        .lineLimit(2...4)
                    
                    // スポット費用
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("spot_spending", comment: "How much will you spend at this spot?"))
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                        HStack {
                            TextField("0", value: $spotCost, format: .number)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 100)
                                .multilineTextAlignment(.center)
                                .keyboardType(.numberPad)
                            Text(NSLocalizedString("yen", comment: "yen"))
                                .font(.system(size: 14))
                        }
                    }
                    
                    // サムネイル画像選択
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("thumbnail_image", comment: "Thumbnail image"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                        
                        PhotosPicker(selection: $selectedThumbnail,
                                    matching: .images,
                                    photoLibrary: .shared()) {
                            if let thumbnailImage {
                                Image(uiImage: thumbnailImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 150)
                                    .frame(maxWidth: .infinity)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color(.systemGray4), lineWidth: 1)
                                    )
                            } else {
                                VStack(spacing: 8) {
                                    Image(systemName: "photo")
                                        .font(.system(size: 40))
                                        .foregroundColor(.gray)
                                    Text(NSLocalizedString("tap_to_select_thumbnail", comment: "Tap to select thumbnail"))
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                }
                                .frame(height: 150)
                                .frame(maxWidth: .infinity)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(.systemGray4), lineWidth: 1)
                                )
                            }
                        }
                        .onChange(of: selectedThumbnail) { _, newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    thumbnailImage = UIImage(data: data)
                                    thumbnailData = data
                                }
                            }
                        }
                    }
                    
                    // 画像選択（複数対応）
                    VStack(alignment: .leading, spacing: 12) {
                        Text(NSLocalizedString("spot_images", comment: "Spot images"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                        
                        // 選択済み画像の表示
                        if !spotImages.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(Array(spotImages.enumerated()), id: \.offset) { index, image in
                                        ZStack(alignment: .topTrailing) {
                                            Image(uiImage: image)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 120, height: 120)
                                                .clipped()
                                                .cornerRadius(8)
                                            
                                            // 削除ボタン
                                            Button(action: {
                                                spotImages.remove(at: index)
                                                spotImagesData.remove(at: index)
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 20))
                                                    .foregroundColor(.white)
                                                    .background(Color.black.opacity(0.7))
                                                    .clipShape(Circle())
                                            }
                                            .padding(4)
                                        }
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                        }
                        
                        // 画像追加ボタン
                        PhotosPicker(selection: $selectedImages,
                                   maxSelectionCount: 10,
                                   matching: .images,
                                   photoLibrary: .shared()) {
                            HStack {
                                Image(systemName: "plus")
                                    .foregroundColor(.blue)
                                Text(NSLocalizedString("add_images_max_10", comment: "Add images (max 10)"))
                                    .foregroundColor(.blue)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.blue, lineWidth: 1)
                            )
                        }
                        .onChange(of: selectedImages) { _, newItems in
                            Task {
                                for item in newItems {
                                    if let data = try? await item.loadTransferable(type: Data.self),
                                       let image = UIImage(data: data) {
                                        spotImages.append(image)
                                        spotImagesData.append(data)
                                    }
                                }
                                selectedImages.removeAll() // 選択をクリア
                            }
                        }
                    }
                }
            }
        }
    
    func calculateDurationFromTimeRange(_ timeRange: String) -> Int {
        // 時間帯の形式: "10:00〜11:30" or "10:00~11:30"
        let components = timeRange.replacingOccurrences(of: "〜", with: "~").split(separator: "~")
        guard components.count == 2 else { return 60 } // デフォルト60分
        
        let startTimeStr = components[0].trimmingCharacters(in: .whitespaces)
        let endTimeStr = components[1].trimmingCharacters(in: .whitespaces)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        guard let startTime = formatter.date(from: startTimeStr),
              let endTime = formatter.date(from: endTimeStr) else { return 60 }
        
        let interval = endTime.timeIntervalSince(startTime)
        let minutes = Int(interval / 60)
        
        return minutes > 0 ? minutes : 60 // 負の値の場合はデフォルト60分
    }
    
    func calculateDurationFromDates(start: Date, end: Date) -> Int {
        let interval = end.timeIntervalSince(start)
        let minutes = Int(interval / 60)
        return minutes > 0 ? minutes : 60 // 負の値の場合はデフォルト60分
    }
}

// 詳細画像セクションのサブビュー
struct DetailImagesSection: View {
    @Binding var detailImagesData: [Data]
    @Binding var existingImageUrls: [String]
    @Binding var selectedDetailImages: [PhotosPickerItem]
    
    var totalImageCount: Int {
        detailImagesData.count + existingImageUrls.count
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // 既存画像の表示
            if totalImageCount > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(format: NSLocalizedString("current_main_images_count", comment: "Current main images (%d)"), totalImageCount))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            // ローカル画像
                            ForEach(0..<detailImagesData.count, id: \.self) { index in
                                if index < detailImagesData.count {
                                    LocalImageView(imageData: detailImagesData[index]) {
                                        detailImagesData.remove(at: index)
                                    }
                                }
                            }
                            
                            // Web画像
                            ForEach(0..<existingImageUrls.count, id: \.self) { index in
                                if index < existingImageUrls.count {
                                    WebImageView(imageUrl: existingImageUrls[index]) {
                                        existingImageUrls.remove(at: index)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
            } else {
                // 画像がない場合の表示
                HStack {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                    Text(NSLocalizedString("no_main_images_added", comment: "No main images added yet"))
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            
            // 画像追加ボタン
            PhotosPicker(
                selection: $selectedDetailImages,
                maxSelectionCount: 5,
                matching: .images,
                photoLibrary: .shared()
            ) {
                HStack(spacing: 8) {
                    Image(systemName: "photo.stack.fill")
                        .font(.system(size: 16, weight: .medium))
                    Text(NSLocalizedString("add_main_image", comment: "Add main image"))
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.orange)
                .cornerRadius(10)
                .shadow(color: Color.orange.opacity(0.3), radius: 3, x: 0, y: 2)
            }
            .buttonStyle(PlainButtonStyle())
            
            Text(NSLocalizedString("max_5_images", comment: "You can add up to 5 images"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// ローカル画像ビュー
struct LocalImageView: View {
    let imageData: Data
    let onDelete: () -> Void
    
    var body: some View {
        if let uiImage = UIImage(data: imageData) {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                
                DeleteButton(action: onDelete)
            }
        }
    }
}

// Web画像ビュー
struct WebImageView: View {
    let imageUrl: String
    let onDelete: () -> Void
    
    var body: some View {
        if let url = URL(string: imageUrl) {
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 120, height: 120)
                        .overlay(
                            ProgressView()
                        )
                }
                
                DeleteButton(action: onDelete)
            }
        }
    }
}

// 削除ボタン
struct DeleteButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.white)
                .background(
                    Circle()
                        .fill(Color.red)
                        .frame(width: 28, height: 28)
                )
                .shadow(radius: 2)
        }
        .offset(x: 6, y: -6)
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
    @State private var timeRange: String
    @State private var startTimeForSpot = Date()
    @State private var endTimeForSpot = Date()
    @State private var activity: String
    @State private var selectedImage: PhotosPickerItem?
    @State private var spotImage: UIImage?
    @State private var spotImageData: Data?
    @State private var spotCost: Int
    @State private var selectedDetailImages: [PhotosPickerItem] = []
    @State private var detailImagesData: [Data] = []
    @State private var existingImageUrls: [String] = []
    
    init(spot: VisitSpot, spots: Binding<[VisitSpot]>, startTime: Date) {
        self.spot = spot
        self._spots = spots
        self.startTime = startTime
        self._spotName = State(initialValue: spot.name)
        self._spotAddress = State(initialValue: spot.address)
        self._nearestStation = State(initialValue: spot.nearestStation)
        self._stayDuration = State(initialValue: spot.stayDuration)
        self._spotNotes = State(initialValue: spot.notes)
        self._timeRange = State(initialValue: spot.timeRange)
        self._activity = State(initialValue: spot.activity)
        self._spotCost = State(initialValue: spot.spotCost)
        if let imageData = spot.imageData {
            self._spotImage = State(initialValue: UIImage(data: imageData))
            self._spotImageData = State(initialValue: imageData)
        }
        if let detailImages = spot.detailImagesData {
            self._detailImagesData = State(initialValue: detailImages)
        }
        self._existingImageUrls = State(initialValue: spot.images)
        
        // timeRangeから時刻を解析
        let components = spot.timeRange.replacingOccurrences(of: "〜", with: "~").split(separator: "~")
        if components.count == 2 {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            let startStr = components[0].trimmingCharacters(in: .whitespaces)
            let endStr = components[1].trimmingCharacters(in: .whitespaces)
            
            if let start = formatter.date(from: startStr),
               let end = formatter.date(from: endStr) {
                self._startTimeForSpot = State(initialValue: start)
                self._endTimeForSpot = State(initialValue: end)
            }
        }
    }
    
    var calculatedStayDuration: Int {
        calculateDurationFromDates(start: startTimeForSpot, end: endTimeForSpot)
    }
    
    var formattedTimeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: startTimeForSpot))〜\(formatter.string(from: endTimeForSpot))"
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("スポット情報") {
                    TextField("スポット名", text: $spotName)
                    
                    // 滞在時間帯選択
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("stay_time_period", comment: "Stay time period"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                        
                        HStack {
                            DatePicker("", selection: $startTimeForSpot, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .frame(width: 100)
                            
                            Text(NSLocalizedString("time_separator", comment: "~"))
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                            
                            DatePicker("", selection: $endTimeForSpot, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .frame(width: 100)
                        }
                        
                        // 計算された滞在時間を表示
                        let duration = calculateDurationFromDates(start: startTimeForSpot, end: endTimeForSpot)
                        if duration > 0 {
                            Text(String(format: NSLocalizedString("stay_duration_format", comment: "Stay duration: %d minutes"), duration))
                                .font(.system(size: 12))
                                .foregroundColor(.blue)
                        }
                    }
                    
                    TextField("住所", text: $spotAddress)
                    
                    TextField("ここで何をするのか", text: $activity, axis: .vertical)
                        .lineLimit(2...4)
                    
                    TextField("メモ", text: $spotNotes, axis: .vertical)
                        .lineLimit(2...4)
                    
                    // スポット費用
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("spot_spending", comment: "How much will you spend at this spot?"))
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                        HStack {
                            TextField("0", value: $spotCost, format: .number)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 100)
                                .multilineTextAlignment(.center)
                                .keyboardType(.numberPad)
                            Text(NSLocalizedString("yen", comment: "yen"))
                                .font(.system(size: 14))
                        }
                    }
                    
                    // サムネイル画像セクション
                    VStack(spacing: 12) {
                        Text(NSLocalizedString("thumbnail_image", comment: "Thumbnail image"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        if let spotImage = spotImage {
                            Image(uiImage: spotImage)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 200)
                                .clipped()
                                .cornerRadius(12)
                                .shadow(radius: 4)
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue.opacity(0.1))
                                .frame(height: 150)
                                .overlay(
                                    VStack(spacing: 8) {
                                        Image(systemName: "photo.badge.plus")
                                            .font(.system(size: 40))
                                            .foregroundColor(.blue)
                                        Text(NSLocalizedString("add_thumbnail_image", comment: "Add thumbnail image"))
                                            .font(.subheadline)
                                            .foregroundColor(.blue)
                                            .fontWeight(.medium)
                                    }
                                )
                        }
                        
                        PhotosPicker(selection: $selectedImage,
                                   matching: .images,
                                   photoLibrary: .shared()) {
                            HStack(spacing: 8) {
                                Image(systemName: "photo.fill")
                                    .font(.system(size: 16, weight: .medium))
                                Text(spotImage != nil ? NSLocalizedString("change_thumbnail", comment: "Change thumbnail") : NSLocalizedString("select_thumbnail", comment: "Select thumbnail"))
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(10)
                            .shadow(color: Color.blue.opacity(0.3), radius: 3, x: 0, y: 2)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .onChange(of: selectedImage) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                await MainActor.run {
                                    spotImage = UIImage(data: data)
                                    spotImageData = data
                                    selectedImage = nil // 選択状態をリセット
                                }
                            }
                        }
                    }
                }
                
                // 詳細画像セクション
                Section(header: Text(NSLocalizedString("detail_images_main", comment: "Detail images (Main images)"))) {
                    DetailImagesSection(
                        detailImagesData: $detailImagesData,
                        existingImageUrls: $existingImageUrls,
                        selectedDetailImages: $selectedDetailImages
                    )
                }
                .onChange(of: selectedDetailImages) { _, newValue in
                    Task {
                        var newDetailImages: [Data] = []
                        for item in newValue {
                            if let data = try? await item.loadTransferable(type: Data.self) {
                                newDetailImages.append(data)
                            }
                        }
                        if !newDetailImages.isEmpty {
                            await MainActor.run {
                                detailImagesData.append(contentsOf: newDetailImages)
                                selectedDetailImages = []
                            }
                        }
                    }
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
                    Button(NSLocalizedString("save", comment: "Save")) {
                        if let index = spots.firstIndex(where: { $0.id == spot.id }) {
                            spots[index].name = spotName
                            spots[index].address = spotAddress
                            spots[index].nearestStation = nearestStation
                            spots[index].stayDuration = calculatedStayDuration
                            spots[index].notes = spotNotes
                            spots[index].timeRange = formattedTimeRange
                            spots[index].activity = activity
                            spots[index].imageData = spotImageData
                            spots[index].spotCost = spotCost
                            spots[index].detailImagesData = detailImagesData.isEmpty ? nil : detailImagesData
                            spots[index].images = existingImageUrls
                        }
                        dismiss()
                    }
                }
            }
        }
    }
    
    func calculateDurationFromTimeRange(_ timeRange: String) -> Int {
        // 時間帯の形式: "10:00〜11:30" or "10:00~11:30"
        let components = timeRange.replacingOccurrences(of: "〜", with: "~").split(separator: "~")
        guard components.count == 2 else { return 60 } // デフォルト60分
        
        let startTimeStr = components[0].trimmingCharacters(in: .whitespaces)
        let endTimeStr = components[1].trimmingCharacters(in: .whitespaces)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        guard let startTime = formatter.date(from: startTimeStr),
              let endTime = formatter.date(from: endTimeStr) else { return 60 }
        
        let interval = endTime.timeIntervalSince(startTime)
        let minutes = Int(interval / 60)
        
        return minutes > 0 ? minutes : 60 // 負の値の場合はデフォルト60分
    }
    
    func calculateDurationFromDates(start: Date, end: Date) -> Int {
        let interval = end.timeIntervalSince(start)
        let minutes = Int(interval / 60)
        return minutes > 0 ? minutes : 60 // 負の値の場合はデフォルト60分
    }
}