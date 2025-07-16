import SwiftUI
import PhotosUI
import Foundation

struct VisitPlanningScreen: View {
    @Environment(\.dismiss) var dismiss
    var draftPlan: VisitPlanData? = nil
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
    @State private var showValidationErrors = false
    @State private var showingPaymentConfirmation = false
    @State private var showingFinalConfirmation = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var showingCompletionView = false
    @State private var createdPlan: VisitPlanData?
    @State private var selectedPlanForNavigation: VisitPlanData?
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
                
                // メインコンテンツ
                ScrollView {
                    VStack(spacing: 24) {
                        // 基本情報セクション
                        VStack(spacing: 16) {
                            // プランタイトル
                            VStack(alignment: .leading, spacing: 8) {
                                Text("プランタイトル")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.gray)
                                TextField("例: 京都の聖地巡礼", text: $planTitle)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .font(.system(size: 16))
                            }
                            
                            // アニメ名
                            VStack(alignment: .leading, spacing: 8) {
                                Text("アニメ名")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.gray)
                                TextField("例: 響け！ユーフォニアム", text: $animeName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .font(.system(size: 16))
                            }
                            
                            // 開始時刻と日数
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
                                    
                                    Menu {
                                        ForEach(1...7, id: \.self) { days in
                                            Button("\(days)日間") {
                                                numberOfDays = days
                                            }
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
                                        .frame(height: 36)
                                        .padding(.horizontal, 12)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                    }
                                }
                            }
                            
                            // サムネイル画像
                            VStack(alignment: .leading, spacing: 8) {
                                Text("サムネイル画像")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.gray)
                                
                                PhotosPicker(selection: $selectedImage, matching: .images, photoLibrary: .shared()) {
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
                                .onChange(of: selectedImage) { _, newItem in
                                    Task {
                                        if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                            thumbnailImage = UIImage(data: data)
                                            thumbnailData = data
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        // スポット管理セクション
                        VStack(spacing: 16) {
                            HStack {
                                Text("スポット")
                                    .font(.system(size: 18, weight: .semibold))
                                Spacer()
                                Button("追加") {
                                    // 簡単なスポット追加（実際の実装では詳細画面を開く）
                                    let newSpot = VisitSpot(
                                        name: "新しいスポット",
                                        address: "",
                                        dayNumber: selectedDay
                                    )
                                    spots.append(newSpot)
                                }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue)
                                .cornerRadius(16)
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
                                ForEach(spots) { spot in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(spot.name)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        if !spot.address.isEmpty {
                                            Text(spot.address)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        // アクションボタン
                        VStack(spacing: 12) {
                            Button("旅程を確認") {
                                showingItinerary = true
                            }
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(spots.isEmpty ? Color.gray : Color.green)
                            )
                            .disabled(spots.isEmpty)
                            
                            Button("下書きを保存") {
                                saveDraft()
                            }
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue, lineWidth: 2)
                            )
                        }
                        .padding(.horizontal, 16)
                        
                        Spacer(minLength: 100)
                    }
                }
                .background(Color(.systemGray6))
            }
        }
        .onAppear {
            if let draft = draftPlan {
                planTitle = draft.title
                animeName = draft.animeName
                spots = draft.spots
                if let data = draft.thumbnailData {
                    thumbnailImage = UIImage(data: data)
                }
                startTime = draft.startTime
                numberOfDays = draft.numberOfDays
            }
        }
        .fullScreenCover(isPresented: $showingItinerary) {
            VisitGameScreen(
                animeName: animeName,
                duration: "不明",
                planTitle: planTitle,
                spots: spots,
                numberOfDays: numberOfDays,
                startTime: startTime,
                onClose: {
                    showingItinerary = false
                    dismiss()
                },
                planId: nil
            )
        }
    }
    
    func saveDraft() {
        let userId = UserDefaults.standard.string(forKey: "userId") ?? {
            let newId = UUID().uuidString
            UserDefaults.standard.set(newId, forKey: "userId")
            return newId
        }()
        
        let visitPlanData = VisitPlanData(
            id: draftPlan?.id ?? UUID(),
            animeName: animeName,
            title: planTitle.isEmpty ? "無題のプラン" : planTitle,
            duration: formatTotalDuration(),
            spots: updateSpotTimes(),
            thumbnailData: thumbnailData,
            thumbnailUrl: nil,
            createdDate: Date(),
            startTime: startTime,
            numberOfDays: numberOfDays,
            isPurchased: false,
            isDraft: true,
            lastVisitedDate: Date()
        )
        
        var savedPlans = UserDefaults.standard.data(forKey: "savedPlans")
            .flatMap { try? JSONDecoder().decode([VisitPlanData].self, from: $0) } ?? []
        
        if let existingIndex = savedPlans.firstIndex(where: { $0.id == visitPlanData.id }) {
            savedPlans[existingIndex] = visitPlanData
        } else {
            savedPlans.append(visitPlanData)
        }
        
        if let encoded = try? JSONEncoder().encode(savedPlans) {
            UserDefaults.standard.set(encoded, forKey: "savedPlans")
        }
        
        print("下書きを保存しました")
    }
    
    func updateSpotTimes() -> [VisitSpot] {
        var updatedSpots = spots
        var currentTime = startTime
        
        for i in 0..<updatedSpots.count {
            updatedSpots[i].arrivalTime = currentTime
            
            let duration = updatedSpots[i].stayDuration
            let departureTime = Calendar.current.date(byAdding: .minute, value: duration, to: currentTime) ?? currentTime
            updatedSpots[i].departureTime = departureTime
            
            if let transport = updatedSpots[i].transportToNext {
                currentTime = Calendar.current.date(byAdding: .minute, value: transport.duration, to: departureTime) ?? departureTime
            } else {
                currentTime = departureTime
            }
        }
        
        return updatedSpots
    }
    
    func formatTotalDuration() -> String {
        let totalMinutes = spots.reduce(0) { total, spot in
            return total + spot.stayDuration + (spot.transportToNext?.duration ?? 0)
        }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return "\(hours)時間\(minutes)分"
    }
    
    func calculateTotalCost() -> Int {
        return spots.reduce(0) { total, spot in
            return total + spot.spotCost + (spot.transportToNext?.cost ?? 0)
        }
    }
}