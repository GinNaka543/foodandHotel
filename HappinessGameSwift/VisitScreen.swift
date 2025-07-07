import SwiftUI
import Foundation
import UIKit

// VisitTypes.swiftの型を使用するための明示的なimport

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
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
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
                        ForEach(VisitTab.allCases, id: \.self) { tab in
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
                                NavigationLink(destination: 
                                    VisitGameScreen(
                                        animeName: plan.animeName,
                                        duration: plan.duration,
                                        spots: plan.spots
                                    )
                                    .navigationBarHidden(true)
                                ) {
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
        .navigationBarHidden(true)
        }
        .onAppear {
            loadSavedPlans()
            
            // デバッグ用: プランがない場合はテストプランを作成
            if savedPlans.isEmpty {
                print("DEBUG: プランが空なのでテストプランを作成します")
                let testSpot1 = VisitSpot(
                    name: "江ノ島駅",
                    address: "神奈川県藤沢市",
                    notes: "スラムダンクの聖地",
                    event: SpotEvent(
                        type: .findLocation,
                        description: "駅を見つけよう"
                    )
                )
                let testSpot2 = VisitSpot(
                    name: "江ノ島海岸",
                    address: "神奈川県藤沢市",
                    notes: "海を眺めよう",
                    event: SpotEvent(
                        type: .takePhoto,
                        description: "海の写真を撮ろう"
                    )
                )
                let testPlan = VisitPlanData(
                    animeName: "スラムダンク",
                    title: "江ノ島聖地巡礼",
                    duration: "1日",
                    spots: [testSpot1, testSpot2]
                )
                savedPlans = [testPlan]
                print("DEBUG: テストプランを追加しました")
            }
        }
    }
    
    func loadSavedPlans() {
        print("DEBUG: loadSavedPlans開始")
        guard let data = UserDefaults.standard.data(forKey: "visitPlans") else {
            print("DEBUG: UserDefaultsにデータがありません")
            return
        }
        
        do {
            let plans = try JSONDecoder().decode([VisitPlanData].self, from: data)
            savedPlans = plans
            print("DEBUG: \(plans.count)個のプランを読み込みました")
            for plan in plans {
                print("DEBUG: プラン: \(plan.title), スポット数: \(plan.spots.count)")
            }
        } catch {
            print("DEBUG: デコードエラー: \(error)")
        }
    }
}




