import SwiftUI

// VisitPlanningScreen.swiftがプロジェクトに追加されるまでの一時的な定義
struct VisitPlanData: Identifiable, Codable {
    let id: UUID
    var animeName: String
    var title: String
    var duration: String
    var spots: [VisitSpot]
    var thumbnailData: Data?
    var createdDate: Date
    
    init(id: UUID = UUID(), animeName: String, title: String, duration: String, spots: [VisitSpot], thumbnailData: Data? = nil, createdDate: Date = Date()) {
        self.id = id
        self.animeName = animeName
        self.title = title
        self.duration = duration
        self.spots = spots
        self.thumbnailData = thumbnailData
        self.createdDate = createdDate
    }
}

struct VisitSpot: Identifiable, Codable {
    let id: UUID
    var name: String
    var address: String
    var notes: String
    var event: SpotEvent?
    
    init(id: UUID = UUID(), name: String, address: String = "", notes: String = "", event: SpotEvent? = nil) {
        self.id = id
        self.name = name
        self.address = address
        self.notes = notes
        self.event = event
    }
}

struct SpotEvent: Identifiable, Codable {
    let id: UUID
    var type: EventType
    var description: String
    var question: String
    var answer: String
    
    init(id: UUID = UUID(), type: EventType, description: String, question: String = "", answer: String = "") {
        self.id = id
        self.type = type
        self.description = description
        self.question = question
        self.answer = answer
    }
}

enum EventType: String, CaseIterable, Codable {
    case findLocation = "場所を探す"
    case takePhoto = "写真を撮る"
    case animeScene = "アニメシーンを探す"
    case animeQuiz = "アニメクイズ"
}

// VisitPlanningScreen.swiftがプロジェクトに追加されるまでの一時的な画面
struct VisitPlanningScreen: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("VisitPlanningScreen.swiftをXcodeプロジェクトに追加してください")
                    .padding()
                
                Button("閉じる") {
                    dismiss()
                }
                .padding()
            }
        }
    }
}

struct VisitGameScreen: View {
    let animeName: String
    let duration: String
    let spots: [VisitSpot]
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack {
            Text("VisitPlanningScreen.swiftをXcodeプロジェクトに追加してください")
                .padding()
            
            Button("閉じる") {
                dismiss()
            }
            .padding()
        }
    }
}

public struct VisitScreen: View {
    @State private var savedPlans: [VisitPlanData] = []
    @State private var showingSelectedPlan = false
    @State private var selectedPlan: VisitPlanData?
    
    // タブ用
    enum VisitTab: String, CaseIterable {
        case all = "ALL"
        case original = "Original"
        case date = "Date"
        case animePilgrimage = "Anime pilgrimage"
        case city = "City"
        case onsen = "Onsen"
    }
    @State private var selectedTab: VisitTab = .all
    @State private var showSearchBar = false
    @State private var searchText = ""
    @State private var showingPlanningScreen = false
    
    public var body: some View {
        NavigationView {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // ヘッダー
                HStack {
                    Button(action: { /* メニュー表示など */ }) {
                        Image(systemName: "line.horizontal.3")
                            .font(.system(size: 28, weight: .regular))
                            .foregroundColor(.black)
                    }
                    Spacer()
                    // 虫眼鏡
                    if showSearchBar {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 22, weight: .regular))
                                .foregroundColor(.gray)
                            TextField("Search", text: $searchText)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.black)
                            Button(action: { withAnimation { showSearchBar = false; searchText = "" } }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 22, weight: .regular))
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .frame(height: 38)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    } else {
                        Button(action: { withAnimation { showSearchBar.toggle() } }) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 24, weight: .regular))
                                .foregroundColor(.black)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 28) // さらに10px上げる
                .offset(y: -10) // さらに10px上にずらす
                // タブUI
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(VisitTab.allCases, id: \ .self) { tab in
                            Button(action: { selectedTab = tab }) {
                                Text(tab.rawValue)
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(selectedTab == tab ? .white : .black)
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(selectedTab == tab ? Color(.darkGray) : Color(.systemGray5))
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                // ビジットプラン欄
                ScrollView {
                    VStack(spacing: 24) {
                        if savedPlans.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "map")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                                Text("まだプランがありません")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                                Text("右下のCreateボタンから作成してください")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 100)
                        } else {
                            ForEach(savedPlans) { plan in
                                Button(action: {
                                    selectedPlan = plan
                                    showingSelectedPlan = true
                                }) {
                                    VStack(alignment: .leading, spacing: 0) {
                                        GeometryReader { geometry in
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 0)
                                                    .fill(Color.white)
                                                    .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
                                                
                                                if let thumbnailData = plan.thumbnailData,
                                                   let uiImage = UIImage(data: thumbnailData) {
                                                    Image(uiImage: uiImage)
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: geometry.size.width, height: 233)
                                                        .clipped()
                                                } else {
                                                    Rectangle()
                                                        .fill(Color(.systemGray5))
                                                        .overlay(
                                                            Image(systemName: "photo")
                                                                .font(.system(size: 40))
                                                                .foregroundColor(.gray)
                                                        )
                                                }
                                            }
                                            .frame(width: geometry.size.width, height: 233)
                                            .clipped()
                                            .padding(.bottom, 0)
                                        }
                                        .frame(height: 233)
                                        HStack(alignment: .center, spacing: 12) {
                                            Circle()
                                                .fill(Color.blue.opacity(0.2))
                                                .frame(width: 40, height: 40)
                                                .overlay(
                                                    Image(systemName: "map.fill")
                                                        .font(.system(size: 20))
                                                        .foregroundColor(.blue)
                                                )
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(plan.title)
                                                    .font(.headline)
                                                    .foregroundColor(.black)
                                                Text("#\(plan.animeName)")
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                            }
                                            Spacer()
                                            VStack(alignment: .trailing, spacing: 2) {
                                                Text(plan.duration)
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundColor(.blue)
                                                Text("\(plan.spots.count)スポット")
                                                    .font(.system(size: 10))
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.vertical, 8)
                            }
                        }
                    }
                    .padding(.top, 8)
                }
                Spacer()
            }
            // Createボタン（右下固定）
            Button(action: { showingPlanningScreen = true }) {
                Text("Create")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.systemBlue))
                    )
            }
            .padding(.bottom, 24)
            .padding(.trailing, 20)
        }
        .fullScreenCover(isPresented: $showingPlanningScreen) {
            VisitPlanningScreen()
                .onDisappear {
                    loadSavedPlans()
                }
        }
        .fullScreenCover(isPresented: $showingSelectedPlan) {
            if let plan = selectedPlan {
                VisitGameScreen(
                    animeName: plan.animeName,
                    duration: plan.duration,
                    spots: plan.spots
                )
            }
        }
        .onAppear {
            loadSavedPlans()
        }
        }
    }
    
    func loadSavedPlans() {
        guard let data = UserDefaults.standard.data(forKey: "visitPlans"),
              let plans = try? JSONDecoder().decode([VisitPlanData].self, from: data) else {
            return
        }
        savedPlans = plans
    }
}

 