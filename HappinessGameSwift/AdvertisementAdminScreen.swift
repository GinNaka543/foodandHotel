import SwiftUI
import Foundation
// Firebase removed - import FirebaseFirestore

struct AdvertisementAdminScreen: View {
    @State private var advertisements: [Advertisement] = []
    @State private var showingAddAdvertisement = false
    @State private var editingAdvertisement: Advertisement?
    @State private var isLoading = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("読み込み中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if advertisements.isEmpty {
                    VStack {
                        Text("広告がありません")
                            .font(.title2)
                            .foregroundColor(.gray)
                        Button("広告を作成") {
                            showingAddAdvertisement = true
                        }
                        .buttonStyle(.borderedProminent)
                        .padding()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(advertisements) { ad in
                            AdvertisementRow(advertisement: ad) {
                                editingAdvertisement = ad
                            } onDelete: {
                                deleteAdvertisement(ad)
                            }
                        }
                    }
                }
            }
            .navigationTitle("広告管理")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        showingAddAdvertisement = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddAdvertisement) {
                AdvertisementEditView(advertisement: nil) { newAd in
                    saveAdvertisement(newAd)
                }
            }
            .sheet(item: $editingAdvertisement) { ad in
                AdvertisementEditView(advertisement: ad) { updatedAd in
                    saveAdvertisement(updatedAd)
                }
            }
            .onAppear {
                loadAdvertisements()
            }
        }
    }
    
    private func loadAdvertisements() {
        // Firebase削除済み - 広告機能を無効化
        isLoading = true
        DispatchQueue.main.async {
            self.isLoading = false
            // 広告は表示しない
            self.advertisements = []
        }
    }
    
    private func saveAdvertisement(_ advertisement: Advertisement) {
        // Firebase削除済み - 広告保存機能を無効化
        // 実際の保存処理は行わない
        DispatchQueue.main.async {
            // UI更新のみ実行
            self.loadAdvertisements()
        }
    }
    
    private func deleteAdvertisement(_ advertisement: Advertisement) {
        // Firebase削除済み - 広告削除機能を無効化
        // 実際の削除処理は行わない
        DispatchQueue.main.async {
            // UI更新のみ実行
            self.loadAdvertisements()
        }
    }
}

struct AdvertisementRow: View {
    private func priorityColor(for level: Int) -> Color {
        switch level {
        case 1...3:
            return .orange
        case 4...7:
            return .blue
        case 8...10:
            return .purple
        default:
            return .gray
        }
    }
    
    let advertisement: Advertisement
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(advertisement.title)
                    .font(.headline)
                Spacer()
                if advertisement.isActive {
                    Text("アクティブ")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(4)
                } else {
                    Text("非アクティブ")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.2))
                        .foregroundColor(.red)
                        .cornerRadius(4)
                }
            }
            
            Text(advertisement.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                Label("\(advertisement.impressions)", systemImage: "eye")
                    .font(.caption)
                Label("\(advertisement.clicks)", systemImage: "hand.tap")
                    .font(.caption)
                Label("\(Int(advertisement.displayRate))%", systemImage: "percent")
                    .font(.caption)
                    .foregroundColor(.orange)
                Label("\(advertisement.priority)", systemImage: "star.fill")
                    .font(.caption)
                    .foregroundColor(priorityColor(for: advertisement.priority))
                Spacer()
                Text(advertisement.placements.joined(separator: ", "))
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
            HStack {
                Button("編集") {
                    onEdit()
                }
                .buttonStyle(.bordered)
                
                Button("削除") {
                    onDelete()
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 8)
    }
}

struct AdvertisementEditView: View {
    let advertisement: Advertisement?
    let onSave: (Advertisement) -> Void
    
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var imageURL: String = ""
    @State private var linkURL: String = ""
    @State private var isLoadingImage = false
    @State private var imageLoadError: String?
    @State private var selectedPlacements: Set<String> = []
    @State private var isActive: Bool = true
    @State private var expiresAt: Date = Date().addingTimeInterval(30 * 24 * 60 * 60)
    @State private var hasExpiration: Bool = false
    @State private var displayRate: Double = 100.0
    @State private var priority: Int = 5
    
    @Environment(\.dismiss) private var dismiss
    
    let availablePlacements = [
        ("home", "ホーム"),
        ("product", "プロダクト"),
        ("character", "キャラクター")
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("基本情報")) {
                    TextField("タイトル", text: $title)
                    TextField("説明", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    
                    VStack(alignment: .leading) {
                        TextField("リンクURL", text: $linkURL)
                            .onChange(of: linkURL) { _, newValue in
                                imageLoadError = nil
                                // GitHub URLの場合は自動で画像を取得
                                if newValue.contains("github.com") && newValue.contains("/blob/") && 
                                   (newValue.hasSuffix(".png") || newValue.hasSuffix(".jpg") || 
                                    newValue.hasSuffix(".jpeg") || newValue.hasSuffix(".gif") || 
                                    newValue.hasSuffix(".webp")) {
                                    fetchImageFromURL()
                                }
                            }
                        
                        HStack {
                            Button(action: {
                                fetchImageFromURL()
                            }) {
                                if isLoadingImage {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Text("画像取得")
                                        .font(.caption)
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(linkURL.isEmpty || isLoadingImage)
                            
                            Text("GitHub画像URLの場合は自動で変換されます")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        
                        if let error = imageLoadError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        HStack {
                            TextField("画像URL", text: $imageURL)
                            
                            Button(action: {
                                // GitHub URLをraw URLに変換
                                if let githubRawURL = ImageExtractor.shared.convertGitHubURLToRaw(imageURL) {
                                    imageURL = githubRawURL
                                }
                            }) {
                                Text("GitHub URL修正")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .disabled(!imageURL.contains("github.com") || !imageURL.contains("/blob/"))
                        }
                        
                        if !imageURL.isEmpty {
                            AsyncImage(url: URL(string: imageURL)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 200)
                                    .cornerRadius(8)
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 100)
                                    .overlay(
                                        Text("画像をプレビュー")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    )
                            }
                        }
                    }
                }
                
                Section(header: Text("表示設定")) {
                    VStack(alignment: .leading) {
                        Text("表示場所")
                            .font(.headline)
                        ForEach(availablePlacements, id: \.0) { placement in
                            HStack {
                                Image(systemName: selectedPlacements.contains(placement.0) ? "checkmark.square.fill" : "square")
                                    .foregroundColor(selectedPlacements.contains(placement.0) ? .blue : .gray)
                                    .onTapGesture {
                                        if selectedPlacements.contains(placement.0) {
                                            selectedPlacements.remove(placement.0)
                                        } else {
                                            selectedPlacements.insert(placement.0)
                                        }
                                    }
                                Text(placement.1)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selectedPlacements.contains(placement.0) {
                                    selectedPlacements.remove(placement.0)
                                } else {
                                    selectedPlacements.insert(placement.0)
                                }
                            }
                        }
                    }
                    
                    Toggle("アクティブ", isOn: $isActive)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("表示率: \(Int(displayRate))%")
                            .font(.headline)
                        Slider(value: $displayRate, in: 0...100, step: 5) {
                            Text("表示率")
                        }
                        Text("この広告が表示される確率を設定します（0-100%）")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("優先度: \(priority)")
                            .font(.headline)
                        Slider(value: Binding(
                            get: { Double(priority) },
                            set: { priority = Int($0) }
                        ), in: 1...10, step: 1) {
                            Text("優先度")
                        }
                        HStack(spacing: 8) {
                            ForEach(1...10, id: \.self) { level in
                                Text("\(level)")
                                    .font(.caption)
                                    .frame(width: 20, height: 20)
                                    .background(level <= priority ? priorityColor(for: level) : Color.gray.opacity(0.2))
                                    .foregroundColor(level <= priority ? .white : .gray)
                                    .clipShape(Circle())
                            }
                        }
                        Text("高い優先度の広告が優先的に表示されます（1-10）")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Toggle("有効期限を設定", isOn: $hasExpiration)
                    if hasExpiration {
                        DatePicker("有効期限", selection: $expiresAt, displayedComponents: [.date])
                    }
                }
            }
            .navigationTitle(advertisement == nil ? "新規広告" : "広告を編集")
            // .navigationBarTitleDisplayMode(.inline) // Removed for macOS compatibility
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .automatic) {
                    Button("保存") {
                        saveAdvertisement()
                    }
                    .disabled(title.isEmpty || selectedPlacements.isEmpty)
                }
            }
            .onAppear {
                if let ad = advertisement {
                    title = ad.title
                    description = ad.description
                    imageURL = ad.imageURL
                    linkURL = ad.linkURL
                    selectedPlacements = Set(ad.placements)
                    isActive = ad.isActive
                    displayRate = ad.displayRate
                    priority = ad.priority
                    if let expires = ad.expiresAt {
                        expiresAt = expires
                        hasExpiration = true
                    }
                }
            }
        }
    }
    
    private func saveAdvertisement() {
        // GitHub URLの場合はraw URLに変換
        var finalImageURL = imageURL
        if let githubRawURL = ImageExtractor.shared.convertGitHubURLToRaw(imageURL) {
            finalImageURL = githubRawURL
        }
        
        let newAd = Advertisement(
            id: advertisement?.id,
            title: title,
            description: description,
            imageURL: finalImageURL,
            linkURL: linkURL,
            priority: priority,
            placements: Array(selectedPlacements),
            isActive: isActive,
            displayRate: displayRate,
            targetAnimes: advertisement?.targetAnimes ?? [],
            targetCharacters: advertisement?.targetCharacters ?? [],
            targetVoiceActors: advertisement?.targetVoiceActors ?? [],
            targetHashtags: advertisement?.targetHashtags ?? [],
            impressions: advertisement?.impressions ?? 0,
            clicks: advertisement?.clicks ?? 0,
            createdAt: advertisement?.createdAt,
            expiresAt: hasExpiration ? expiresAt : nil
        )
        
        onSave(newAd)
        dismiss()
    }
    
    private func priorityColor(for level: Int) -> Color {
        switch level {
        case 1...3:
            return .orange
        case 4...7:
            return .blue
        case 8...10:
            return .purple
        default:
            return .gray
        }
    }
    
    private func fetchImageFromURL() {
        guard !linkURL.isEmpty else { return }
        
        isLoadingImage = true
        imageLoadError = nil
        
        ImageExtractor.shared.extractFirstImageURL(from: linkURL) { result in
            isLoadingImage = false
            
            switch result {
            case .success(let extractedImageURL):
                imageURL = extractedImageURL
                imageLoadError = nil
            case .failure(_):
                imageLoadError = "画像を取得できませんでした"
            }
        }
    }
}