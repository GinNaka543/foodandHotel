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
    @State private var showingPublicationChoice = false
    @State private var showingPublishDialog = false
    @State private var showingPaymentSheet = false
    @State private var showingPublicationConfirmation = false
    @State private var showValidationErrors = false
    @StateObject private var firebaseManager = FirebaseManager.shared
    @StateObject private var stripeManager = StripePaymentManager.shared
    @StateObject private var githubManager = GitHubImageManager.shared
    
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
                            
                            // 開始時刻と旅行日数
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("開始時刻")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.gray)
                                    DatePicker("", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                                        .datePickerStyle(CompactDatePickerStyle())
                                        .labelsHidden()
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("旅行日数")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.gray)
                                    
                                    if numberOfDays <= 7 {
                                        Menu {
                                            ForEach(1...7, id: \.self) { days in
                                                Button("\(days)日間") {
                                                    numberOfDays = days
                                                }
                                            }
                                            Divider()
                                            Button("カスタマイズ") {
                                                showingCustomDaysPicker = true
                                            }
                                        } label: {
                                            HStack {
                                                Text("\(numberOfDays)日間")
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
                                                Button("\(days)日間") {
                                                    numberOfDays = days
                                                }
                                            }
                                            Divider()
                                            Button("カスタマイズ") {
                                                showingCustomDaysPicker = true
                                            }
                                        } label: {
                                            HStack {
                                                Text("\(numberOfDays)日間")
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
                                }
                            }
                            
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
                                    Text("概要")
                                        .font(.system(size: 16, weight: .semibold))
                                    Spacer()
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
                VStack(spacing: 12) {
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
                    
                    HStack(spacing: 16) {
                        Button(action: {
                            saveDraft()
                        }) {
                            Text("下書きを保存")
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
                            if planTitle.isEmpty || animeName.isEmpty || spots.isEmpty {
                                showValidationErrors = true
                            } else {
                                showingPublicationChoice = true
                            }
                        }) {
                            Text("プランを確定")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.purple)
                                )
                        }
                        .disabled(planTitle.isEmpty || animeName.isEmpty || spots.isEmpty)
                .padding(.horizontal)
                
                // 記載漏れの警告表示（ボタンクリック後のみ）
                if showValidationErrors {
                    VStack(alignment: .leading, spacing: 4) {
                        if animeName.isEmpty {
                            Label("アニメ名を入力してください", systemImage: "exclamationmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.red)
                        }
                        if planTitle.isEmpty {
                            Label("プランタイトルを入力してください", systemImage: "exclamationmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.red)
                        }
                        if spots.isEmpty {
                            Label("スポットを追加してください", systemImage: "exclamationmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingPublicationChoice) {
            PlanPublicationChoiceView(
                planTitle: planTitle,
                onPrivate: { 
                    isPublic = false
                    showingPublicationChoice = false
                    savePlanPrivately()
                },
                onPublic: { 
                    isPublic = true
                    showingPublicationChoice = false
                    showingPublishDialog = true
                },
                onCancel: { showingPublicationChoice = false }
            )
        }
        .sheet(isPresented: $showingPublishDialog) {
            PublishPlanDialog(
                planTitle: planTitle,
                planDescription: $planDescription,
                planPrice: $planPrice,
                planBudget: $planBudget,
                onPublish: { 
                    showingPublishDialog = false
                    showingPublicationConfirmation = true
                },
                onCancel: { showingPublishDialog = false }
            )
        }
        .sheet(isPresented: $showingPublicationConfirmation) {
            PlanPublicationConfirmationView(
                planTitle: planTitle,
                onConfirm: { publishPlan() },
                onCancel: { showingPublicationConfirmation = false }
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
                startTime: startTime
            )
        }
        .onChange(of: planTitle) { _ in
            if !planTitle.isEmpty && !animeName.isEmpty && !spots.isEmpty {
                showValidationErrors = false
            }
        }
        .onChange(of: animeName) { _ in
            if !planTitle.isEmpty && !animeName.isEmpty && !spots.isEmpty {
                showValidationErrors = false
            }
        }
        .onChange(of: spots) { _ in
            if !planTitle.isEmpty && !animeName.isEmpty && !spots.isEmpty {
                showValidationErrors = false
            }
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
    
    func savePlanPrivately() {
        // プライベートプランとして保存（支払い不要）
        uploadPlanToFirebase(payment: nil, isPublic: false)
    }
    
    func publishPlan() {
        // 予算チェック
        guard planBudget > 0 else {
            print("予算が設定されていません")
            return
        }
        
        let userId = UserDefaults.standard.string(forKey: "userId") ?? {
            let newId = UUID().uuidString
            UserDefaults.standard.set(newId, forKey: "userId")
            return newId
        }()
        let publicationCost = 5000
        
        // 5000ポイントを消費
        firebaseManager.usePoints(userId: userId, points: publicationCost, description: "プラン公開", completion: { result in
            switch result {
            case .success:
                print("ポイント消費成功: \(publicationCost)ポイント")
                // ポイント消費成功後、プランをFirebaseに保存
                self.uploadPlanToFirebase(payment: nil, isPublic: true)
            case .failure(let error):
                print("ポイント消費エラー: \(error)")
                // エラー処理（ポイント不足など）
                DispatchQueue.main.async {
                    self.showingPublicationConfirmation = false
                }
            }
        })
    }
    
    func uploadPlanToFirebase(payment: PlanPostingPayment?, isPublic: Bool) {
        let userId = UserDefaults.standard.string(forKey: "userId") ?? {
            let newId = UUID().uuidString
            UserDefaults.standard.set(newId, forKey: "userId")
            return newId
        }()
        
        // 画像をGitHubにアップロード（公開プランの場合のみ）
        var thumbnailUrl: String?
        let group = DispatchGroup()
        
        if isPublic && thumbnailImage != nil {
            group.enter()
            githubManager.uploadImage(thumbnailImage!, fileName: "plan_\(UUID().uuidString)") { result in
                switch result {
                case .success(let url):
                    thumbnailUrl = url
                case .failure(let error):
                    print("画像アップロードエラー: \(error)")
                }
                group.leave()
            }
        }
        
        group.notify(queue: DispatchQueue.main, execute: {
            // プランデータを作成
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
            
            print("🔍 [DEBUG] 保存するプランデータ:")
            print("  - id: \(plan.id)")
            print("  - userId: \(plan.userId)")
            print("  - title: \(plan.title)")
            print("  - isPublic: \(plan.isPublic)")
            
            if isPublic {
                // 公開プランはFirebaseに保存
                self.firebaseManager.saveVisitPlan(plan) { result in
                    switch result {
                    case .success:
                        print("✅ 公開プラン保存成功: \(plan.title)")
                        if let payment = payment {
                            // 支払い記録を保存
                            self.firebaseManager.recordPlanPostingPayment(payment) { _ in
                            DispatchQueue.main.async {
                                self.dismiss()
                            }
                        }
                    } else {
                        // プライベートプランまたは公開プランの場合はそのまま閉じる
                        DispatchQueue.main.async {
                            self.showingPublicationConfirmation = false
                            self.dismiss()
                        }
                    }
                case .failure(let error):
                    print("プラン保存エラー: \(error)")
                }
            }
            } else {
                // 非公開プランはローカルに保存
                // 既存のプランを読み込む
                var plans = self.getSavedPlans()
                
                // VisitPlanModelからVisitPlanDataへ変換
                var planData = VisitPlanData(
                    id: UUID(uuidString: plan.id) ?? UUID(),
                    animeName: plan.animeName,
                    title: plan.title,
                    duration: plan.duration,
                    spots: plan.spots,
                    thumbnailData: self.thumbnailImage?.jpegData(compressionQuality: 0.8),
                    createdDate: plan.createdDate,
                    startTime: plan.startTime,
                    numberOfDays: plan.numberOfDays
                )
                planData.totalCost = plan.totalCost
                
                // 新しいプランを先頭に追加（最新順）
                plans.insert(planData, at: 0)
                
                // UserDefaultsに保存
                if let encodedData = try? JSONEncoder().encode(plans) {
                    UserDefaults.standard.set(encodedData, forKey: "visitPlans")
                    print("✅ 非公開プラン保存成功: \(plan.title)")
                    
                    DispatchQueue.main.async {
                        self.dismiss()
                    }
                }
            }
        })
    }
    
    func saveDraft() {
        let userId = UserDefaults.standard.string(forKey: "userId") ?? {
            let newId = UUID().uuidString
            UserDefaults.standard.set(newId, forKey: "userId")
            return newId
        }()
        
        // 下書きプランを作成（isPublicをfalseに設定）
        let plan = VisitPlanModel(
            id: UUID().uuidString,
            userId: userId,
            animeName: animeName,
            title: planTitle.isEmpty ? "無題のプラン" : planTitle,
            description: planDescription,
            duration: formatTotalDuration(),
            spots: updateSpotTimes(),
            thumbnailUrl: nil,
            price: 0,
            budget: calculateTotalCost(), // 下書きの場合は総費用を予算として設定
            createdDate: Date(),
            startTime: startTime,
            numberOfDays: numberOfDays,
            totalCost: calculateTotalCost(),
            isPublic: false, // 下書きは非公開
            purchasedBy: [],
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // Firebaseに下書きとして保存
        firebaseManager.saveVisitPlan(plan) { result in
            switch result {
            case .success:
                print("下書き保存成功: \(plan.title)")
                DispatchQueue.main.async {
                    self.dismiss()
                }
            case .failure(let error):
                print("下書き保存エラー: \(error)")
            }
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
                    
                    Text("日間")
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
    // サムネイル画像用
    @State private var selectedThumbnailItem: PhotosPickerItem?
    @State private var spotThumbnailImage: UIImage?
    @State private var spotThumbnailData: Data?
    // 詳細画像用
    @State private var selectedDetailImages: [PhotosPickerItem] = []
    @State private var spotDetailImages: [UIImage] = []
    @State private var spotDetailImagesData: [Data] = []
    @State private var transportMethod: String = "電車"
    @State private var transportDuration: Int = 30
    @State private var transportCost: Int = 0
    @State private var transportRoute: String = ""
    
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
        let components = lastSpot.timeRange.replacingOccurrences(of: "〜", with: "~").split(separator: "~")
        if components.count == 2 {
            return components[1].trimmingCharacters(in: .whitespaces)
        }
        return nil
    }
    
    var body: some View {
        NavigationView {
            Form {
                // 前のスポットの終了時刻を表示
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
                
                // 交通手段セクションを上に配置
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
                            Text("どのくらい時間がかかりますか？")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                            HStack {
                                TextField("30", value: $transportDuration, format: .number)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 60)
                                    .multilineTextAlignment(.center)
                                Text("分")
                                    .font(.system(size: 14))
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("交通費はいくらですか？")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                            HStack {
                                TextField("0", value: $transportCost, format: .number)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 80)
                                    .multilineTextAlignment(.center)
                                Text("円")
                                    .font(.system(size: 14))
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("どのルートを使いますか？（任意）")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                            TextField("例：JR山手線 → 東京メトロ銀座線", text: $transportRoute)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                }
                
                Section("スポット情報 - Day \(selectedDay)") {
                    TextField("スポット名", text: $spotName)
                    
                    // 滞在時間帯選択
                    VStack(alignment: .leading, spacing: 8) {
                        Text("滞在時間帯")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                        
                        HStack {
                            DatePicker("", selection: $startTimeForSpot, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .frame(width: 100)
                            
                            Text("〜")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                            
                            DatePicker("", selection: $endTimeForSpot, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .frame(width: 100)
                        }
                        
                        // 計算された滞在時間を表示
                        let duration = calculateDurationFromDates(start: startTimeForSpot, end: endTimeForSpot)
                        if duration > 0 {
                            Text("滞在時間: \(duration)分")
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
                        Text("このスポットでいくら使いますか？")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                        HStack {
                            TextField("0", value: $spotCost, format: .number)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 100)
                                .multilineTextAlignment(.center)
                                .keyboardType(.numberPad)
                            Text("円")
                                .font(.system(size: 14))
                        }
                    }
                    
                    // サムネイル画像選択
                    VStack(alignment: .leading, spacing: 12) {
                        Text("サムネイル画像（メイン画像）")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                        
                        // サムネイル画像の表示
                        PhotosPicker(selection: $selectedThumbnailItem,
                                   matching: .images,
                                   photoLibrary: .shared()) {
                            if let spotThumbnailImage = spotThumbnailImage {
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: spotThumbnailImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 200, height: 120)
                                        .clipped()
                                        .cornerRadius(8)
                                    
                                    // 削除ボタン
                                    Button(action: {
                                        self.spotThumbnailImage = nil
                                        self.spotThumbnailData = nil
                                        self.selectedThumbnailItem = nil
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(.white)
                                            .background(Color.black.opacity(0.7))
                                            .clipShape(Circle())
                                    }
                                    .padding(4)
                                }
                            } else {
                                HStack {
                                    Image(systemName: "photo")
                                        .foregroundColor(.blue)
                                    Text("サムネイルを選択")
                                        .foregroundColor(.blue)
                                }
                                .frame(width: 200, height: 120)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.blue, lineWidth: 1)
                                )
                            }
                        }
                        .onChange(of: selectedThumbnailItem) { newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self),
                                   let image = UIImage(data: data) {
                                    spotThumbnailImage = image
                                    spotThumbnailData = data
                                }
                            }
                        }
                    }
                    
                    // 詳細画像選択（予約情報などのスクショ）
                    VStack(alignment: .leading, spacing: 12) {
                        Text("詳細画像（予約情報・地図など）")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                        
                        // 選択済み詳細画像の表示
                        if !spotDetailImages.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(Array(spotDetailImages.enumerated()), id: \.offset) { index, image in
                                        ZStack(alignment: .topTrailing) {
                                            Image(uiImage: image)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 120, height: 120)
                                                .clipped()
                                                .cornerRadius(8)
                                            
                                            // 削除ボタン
                                            Button(action: {
                                                spotDetailImages.remove(at: index)
                                                spotDetailImagesData.remove(at: index)
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
                        
                        // 詳細画像追加ボタン
                        PhotosPicker(selection: $selectedDetailImages,
                                   maxSelectionCount: 10,
                                   matching: .images,
                                   photoLibrary: .shared()) {
                            HStack {
                                Image(systemName: "plus")
                                    .foregroundColor(.blue)
                                Text("詳細画像を追加（最大10枚）")
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
                        .onChange(of: selectedDetailImages) { newItems in
                            Task {
                                for item in newItems {
                                    if let data = try? await item.loadTransferable(type: Data.self),
                                       let image = UIImage(data: data) {
                                        spotDetailImages.append(image)
                                        spotDetailImagesData.append(data)
                                    }
                                }
                                selectedDetailImages.removeAll() // 選択をクリア
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
                            timeRange: formattedTimeRange,
                            activity: activity,
                            imageData: spotThumbnailData, // サムネイル画像
                            detailImagesData: spotDetailImagesData.isEmpty ? nil : spotDetailImagesData, // 詳細画像
                            dayNumber: selectedDay,
                            spotCost: spotCost
                        )
                        spots.append(newSpot)
                        dismiss()
                    }
                    .disabled(spotName.isEmpty)
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
    // サムネイル画像用
    @State private var selectedThumbnailItem: PhotosPickerItem?
    @State private var spotThumbnailImage: UIImage?
    @State private var spotThumbnailData: Data?
    // 詳細画像用
    @State private var selectedDetailImages: [PhotosPickerItem] = []
    @State private var spotDetailImages: [UIImage] = []
    @State private var spotDetailImagesData: [Data] = []
    @State private var spotCost: Int
    
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
        // サムネイル画像の初期化
        if let imageData = spot.imageData {
            self._spotThumbnailImage = State(initialValue: UIImage(data: imageData))
            self._spotThumbnailData = State(initialValue: imageData)
        }
        
        // 詳細画像の初期化
        if let detailImagesData = spot.detailImagesData {
            let images = detailImagesData.compactMap { UIImage(data: $0) }
            self._spotDetailImages = State(initialValue: images)
            self._spotDetailImagesData = State(initialValue: detailImagesData)
        }
        
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
                        Text("滞在時間帯")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                        
                        HStack {
                            DatePicker("", selection: $startTimeForSpot, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .frame(width: 100)
                            
                            Text("〜")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                            
                            DatePicker("", selection: $endTimeForSpot, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .frame(width: 100)
                        }
                        
                        // 計算された滞在時間を表示
                        let duration = calculateDurationFromDates(start: startTimeForSpot, end: endTimeForSpot)
                        if duration > 0 {
                            Text("滞在時間: \(duration)分")
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
                        Text("このスポットでいくら使いますか？")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                        HStack {
                            TextField("0", value: $spotCost, format: .number)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 100)
                                .multilineTextAlignment(.center)
                                .keyboardType(.numberPad)
                            Text("円")
                                .font(.system(size: 14))
                        }
                    }
                    
                    // サムネイル画像選択
                    VStack(alignment: .leading, spacing: 12) {
                        Text("サムネイル画像（メイン画像）")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                        
                        PhotosPicker(selection: $selectedThumbnailItem,
                                   matching: .images,
                                   photoLibrary: .shared()) {
                            if let spotThumbnailImage = spotThumbnailImage {
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: spotThumbnailImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 150)
                                        .clipped()
                                        .cornerRadius(8)
                                    
                                    // 削除ボタン
                                    Button(action: {
                                        self.spotThumbnailImage = nil
                                        self.spotThumbnailData = nil
                                        self.selectedThumbnailItem = nil
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(.white)
                                            .background(Color.black.opacity(0.7))
                                            .clipShape(Circle())
                                    }
                                    .padding(4)
                                }
                            } else {
                                HStack {
                                    Image(systemName: "photo")
                                        .foregroundColor(.gray)
                                    Text("サムネイルを選択")
                                        .foregroundColor(.gray)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 100)
                                .background(Color(.systemGray5))
                                .cornerRadius(8)
                            }
                        }
                        .onChange(of: selectedThumbnailItem) { newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                    spotThumbnailImage = UIImage(data: data)
                                    spotThumbnailData = data
                                }
                            }
                        }
                    }
                    
                    // 詳細画像選択
                    VStack(alignment: .leading, spacing: 12) {
                        Text("詳細画像（予約情報・地図など）")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                        
                        // 選択済み詳細画像の表示
                        if !spotDetailImages.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(Array(spotDetailImages.enumerated()), id: \.offset) { index, image in
                                        ZStack(alignment: .topTrailing) {
                                            Image(uiImage: image)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 100, height: 100)
                                                .clipped()
                                                .cornerRadius(8)
                                            
                                            // 削除ボタン
                                            Button(action: {
                                                spotDetailImages.remove(at: index)
                                                spotDetailImagesData.remove(at: index)
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 16))
                                                    .foregroundColor(.white)
                                                    .background(Color.black.opacity(0.7))
                                                    .clipShape(Circle())
                                            }
                                            .padding(2)
                                        }
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                        }
                        
                        // 詳細画像追加ボタン
                        PhotosPicker(selection: $selectedDetailImages,
                                   maxSelectionCount: 10,
                                   matching: .images,
                                   photoLibrary: .shared()) {
                            HStack {
                                Image(systemName: "plus")
                                    .foregroundColor(.blue)
                                Text("詳細画像を追加")
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
                        .onChange(of: selectedDetailImages) { newItems in
                            Task {
                                for item in newItems {
                                    if let data = try? await item.loadTransferable(type: Data.self),
                                       let image = UIImage(data: data) {
                                        spotDetailImages.append(image)
                                        spotDetailImagesData.append(data)
                                    }
                                }
                                selectedDetailImages.removeAll()
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
                    Button("保存") {
                        if let index = spots.firstIndex(where: { $0.id == spot.id }) {
                            spots[index].name = spotName
                            spots[index].address = spotAddress
                            spots[index].nearestStation = nearestStation
                            spots[index].stayDuration = calculatedStayDuration
                            spots[index].notes = spotNotes
                            spots[index].timeRange = formattedTimeRange
                            spots[index].activity = activity
                            spots[index].imageData = spotThumbnailData
                            spots[index].detailImagesData = spotDetailImagesData.isEmpty ? nil : spotDetailImagesData
                            spots[index].spotCost = spotCost
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