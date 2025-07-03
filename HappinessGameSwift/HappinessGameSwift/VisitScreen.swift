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
    
    public var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            HStack {
                Button(action: { /* メニュー表示など */ }) {
                    Image(systemName: "line.horizontal.3")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.black)
                }
                Spacer()
                Button(action: { /* 追加処理 */ }) {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.black)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            // 検索バー
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color(.systemGray3))
                    .font(.system(size: 18))
                TextField("Search", text: .constant(""))
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .font(.system(size: 16))
                    .foregroundColor(.black)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
            .background(Color.white)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
            .frame(height: 38)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            // インフォメーションタイトル
            HStack {
                Text("Information")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
            }
            .padding(.top, 16)
            .padding(.horizontal, 20)
            // ビジットプラン欄
            ScrollView {
                VStack(spacing: 24) {
                    ForEach(visitPlans) { plan in
                        VStack(spacing: 0) {
                            if let image = UIImage(named: plan.imageName) {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 360, height: 189)
                                    .cornerRadius(10)
                                    .clipped()
                                    .padding(.top, 20)
                            }
                            HStack(alignment: .center, spacing: 12) {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Image(systemName: plan.iconName)
                                            .font(.system(size: 20))
                                            .foregroundColor(.gray)
                                    )
                                Text(plan.title)
                                    .font(.headline)
                                    .foregroundColor(.black)
                            }
                            .padding(.top, 8)
                            .padding(.leading, 8)
                        }
                    }
                }
                .padding(.top, 8)
            }
            Spacer()
        }
    }
} 