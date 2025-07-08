import SwiftUI
import Firebase

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
                ToolbarItem(placement: .navigationBarTrailing) {
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
        isLoading = true
        let db = Firestore.firestore()
        
        db.collection("advertisements")
            .order(by: "createdAt", descending: true)
            .getDocuments { snapshot, error in
                isLoading = false
                
                if let error = error {
                    errorMessage = "エラー: \(error.localizedDescription)"
                    return
                }
                
                advertisements = snapshot?.documents.compactMap { doc in
                    let data = doc.data()
                    return Advertisement(
                        id: doc.documentID,
                        title: data["title"] as? String ?? "",
                        description: data["description"] as? String ?? "",
                        imageURL: data["imageURL"] as? String ?? "",
                        linkURL: data["linkURL"] as? String ?? "",
                        targetAnimes: data["targetAnimes"] as? [String] ?? [],
                        targetCharacters: data["targetCharacters"] as? [String] ?? [],
                        targetHashtags: data["targetHashtags"] as? [String] ?? [],
                        placements: data["placements"] as? [String] ?? [],
                        impressions: data["impressions"] as? Int ?? 0,
                        clicks: data["clicks"] as? Int ?? 0,
                        isActive: data["isActive"] as? Bool ?? true,
                        createdAt: (data["createdAt"] as? Timestamp)?.dateValue(),
                        expiresAt: (data["expiresAt"] as? Timestamp)?.dateValue()
                    )
                } ?? []
            }
    }
    
    private func saveAdvertisement(_ advertisement: Advertisement) {
        let db = Firestore.firestore()
        var data: [String: Any] = [
            "title": advertisement.title,
            "description": advertisement.description,
            "imageURL": advertisement.imageURL,
            "linkURL": advertisement.linkURL,
            "targetAnimes": advertisement.targetAnimes,
            "targetCharacters": advertisement.targetCharacters,
            "targetHashtags": advertisement.targetHashtags,
            "placements": advertisement.placements,
            "isActive": advertisement.isActive,
            "impressions": advertisement.impressions,
            "clicks": advertisement.clicks
        ]
        
        if advertisement.createdAt == nil {
            data["createdAt"] = FieldValue.serverTimestamp()
        }
        
        if let expiresAt = advertisement.expiresAt {
            data["expiresAt"] = Timestamp(date: expiresAt)
        }
        
        if let id = advertisement.id {
            db.collection("advertisements").document(id).setData(data) { error in
                if let error = error {
                    errorMessage = "保存エラー: \(error.localizedDescription)"
                } else {
                    loadAdvertisements()
                }
            }
        } else {
            db.collection("advertisements").addDocument(data: data) { error in
                if let error = error {
                    errorMessage = "作成エラー: \(error.localizedDescription)"
                } else {
                    loadAdvertisements()
                }
            }
        }
    }
    
    private func deleteAdvertisement(_ advertisement: Advertisement) {
        guard let id = advertisement.id else { return }
        
        let db = Firestore.firestore()
        db.collection("advertisements").document(id).delete { error in
            if let error = error {
                errorMessage = "削除エラー: \(error.localizedDescription)"
            } else {
                loadAdvertisements()
            }
        }
    }
}

struct AdvertisementRow: View {
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
    @State private var selectedPlacements: Set<String> = []
    @State private var isActive: Bool = true
    @State private var expiresAt: Date = Date().addingTimeInterval(30 * 24 * 60 * 60)
    @State private var hasExpiration: Bool = false
    
    @Environment(\.dismiss) private var dismiss
    
    let availablePlacements = [
        ("home", "ホーム"),
        ("product", "プロダクト"),
        ("character", "キャラクター")
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section("基本情報") {
                    TextField("タイトル", text: $title)
                    TextField("説明", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("画像URL", text: $imageURL)
                    TextField("リンクURL", text: $linkURL)
                }
                
                Section("表示設定") {
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
                    
                    Toggle("有効期限を設定", isOn: $hasExpiration)
                    if hasExpiration {
                        DatePicker("有効期限", selection: $expiresAt, displayedComponents: [.date])
                    }
                }
            }
            .navigationTitle(advertisement == nil ? "新規広告" : "広告を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
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
                    if let expires = ad.expiresAt {
                        expiresAt = expires
                        hasExpiration = true
                    }
                }
            }
        }
    }
    
    private func saveAdvertisement() {
        let newAd = Advertisement(
            id: advertisement?.id,
            title: title,
            description: description,
            imageURL: imageURL,
            linkURL: linkURL,
            targetAnimes: advertisement?.targetAnimes ?? [],
            targetCharacters: advertisement?.targetCharacters ?? [],
            targetHashtags: advertisement?.targetHashtags ?? [],
            placements: Array(selectedPlacements),
            impressions: advertisement?.impressions ?? 0,
            clicks: advertisement?.clicks ?? 0,
            isActive: isActive,
            createdAt: advertisement?.createdAt,
            expiresAt: hasExpiration ? expiresAt : nil
        )
        
        onSave(newAd)
        dismiss()
    }
}