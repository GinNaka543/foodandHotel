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
            // 広告バナー追加
            AdBannerView()
                .padding(.vertical, 2)
            // ビジットプラン欄
            ScrollView {
                VStack(spacing: 24) {
                    ForEach(visitPlans) { plan in
                        VStack(alignment: .leading, spacing: 0) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(Color.white)
                                    .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
                                Image(plan.imageName)
                                    .resizable()
                                    .aspectRatio(370.0/233.0, contentMode: .fill)
                                    .frame(width: 370, height: 233)
                                    .clipShape(RoundedRectangle(cornerRadius: 24))
                            }
                            .frame(width: 370, height: 233)
                            .clipped()
                            .padding(.bottom, 0)
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
                        .frame(width: 370)
                        .padding(.vertical, 8)
                    }
                }
                .padding(.top, 8)
            }
            Spacer()
        }
    }
} 