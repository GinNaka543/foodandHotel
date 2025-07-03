import SwiftUI

struct VisitPlan: Identifiable {
    let id = UUID()
    let imageName: String
    let title: String
    let iconName: String
}

public struct VisitScreen: View {
    // 仮のビジットプランデータ
    let visitPlans: [VisitPlan] = [
        VisitPlan(imageName: "青豚", title: "アートウォーク", iconName: "paintbrush")
    ]
    
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
    
    public var body: some View {
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
                        ForEach(visitPlans) { plan in
                            VStack(alignment: .leading, spacing: 0) {
                                GeometryReader { geometry in
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 0)
                                            .fill(Color.white)
                                            .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
                                        Image(plan.imageName)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: geometry.size.width, height: 233)
                                            .clipped()
                                    }
                                    .frame(width: geometry.size.width, height: 233)
                                    .clipped()
                                    .padding(.bottom, 0)
                                }
                                .frame(height: 233)
                                HStack(alignment: .center, spacing: 12) {
                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Image(systemName: plan.iconName)
                                                .font(.system(size: 20))
                                                .foregroundColor(.gray)
                                        )
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(plan.title)
                                            .font(.headline)
                                            .foregroundColor(.black)
                                        Text("#nakajimaginsei")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding(.top, 8)
                                .padding(.leading, 8)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .padding(.top, 8)
                }
                Spacer()
            }
            // Createボタン（右下固定）
            Button(action: { /* 追加処理 */ }) {
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
    }
} 