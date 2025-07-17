import SwiftUI
import PhotosUI

struct SpotEditView: View {
    @Binding var spot: VisitSpot
    let onSave: () -> Void
    let onCancel: () -> Void
    
    @State private var name: String = ""
    @State private var address: String = ""
    @State private var notes: String = ""
    @State private var activity: String = ""
    @State private var stayDuration: String = ""
    @State private var spotCost: String = ""
    @State private var selectedImage: PhotosPickerItem?
    @State private var selectedDetailImages: [PhotosPickerItem] = []
    @State private var imageData: Data?
    @State private var detailImagesData: [Data] = []
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("基本情報")) {
                    TextField("スポット名", text: $name)
                    TextField("住所", text: $address)
                    TextField("ここで何をするか", text: $activity)
                }
                
                Section(header: Text("時間と費用")) {
                    HStack {
                        Text("滞在時間")
                        Spacer()
                        TextField("60", text: $stayDuration)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("分")
                    }
                    
                    HStack {
                        Text("費用")
                        Spacer()
                        Text("¥")
                        TextField("0", text: $spotCost)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                }
                
                Section(header: Text("スポット画像")) {
                    VStack(spacing: 16) {
                        // 現在の画像表示
                        if let imageData = imageData,
                           let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .cornerRadius(12)
                                .shadow(radius: 4)
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 150)
                                .overlay(
                                    VStack(spacing: 8) {
                                        Image(systemName: "photo")
                                            .font(.system(size: 50))
                                            .foregroundColor(.blue)
                                        Text("スポットの画像を追加")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                )
                        }
                        
                        // 画像選択ボタン
                        PhotosPicker(
                            selection: $selectedImage,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            HStack(spacing: 8) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 18, weight: .medium))
                                Text(imageData != nil ? "画像を変更" : "画像を選択")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                            .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.vertical, 8)
                }
                
                Section(header: Text("メモ")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
                
                
                Section(header: Text("詳細画像（予約情報など）")) {
                    VStack(spacing: 12) {
                        if !detailImagesData.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(Array(detailImagesData.enumerated()), id: \.offset) { index, data in
                                        if let uiImage = UIImage(data: data) {
                                            ZStack(alignment: .topTrailing) {
                                                Image(uiImage: uiImage)
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 100, height: 100)
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                                
                                                Button(action: {
                                                    detailImagesData.remove(at: index)
                                                }) {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .font(.system(size: 20))
                                                        .foregroundColor(.red)
                                                        .background(Color.white.clipShape(Circle()))
                                                }
                                                .offset(x: 8, y: -8)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                        }
                        
                        PhotosPicker(
                            selection: $selectedDetailImages,
                            maxSelectionCount: 5,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            HStack(spacing: 8) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 16, weight: .medium))
                                Text("詳細画像を追加")
                                    .font(.system(size: 15, weight: .medium))
                            }
                            .foregroundColor(.blue)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("スポットを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveChanges()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            // 既存のデータを読み込み
            name = spot.name
            address = spot.address
            notes = spot.notes
            activity = spot.activity
            stayDuration = String(spot.stayDuration)
            spotCost = String(spot.spotCost)
            imageData = spot.imageData
            detailImagesData = spot.detailImagesData ?? []
        }
        .onChange(of: selectedImage) { oldValue, newValue in
            Task {
                if let newImage = newValue,
                   let data = try? await newImage.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        imageData = data
                        selectedImage = nil // 選択状態をリセット
                    }
                }
            }
        }
        .onChange(of: selectedDetailImages) { oldValue, newValue in
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
    }
    
    func saveChanges() {
        // 変更を保存
        spot.name = name
        spot.address = address
        spot.notes = notes
        spot.activity = activity
        spot.stayDuration = Int(stayDuration) ?? 60
        spot.spotCost = Int(spotCost) ?? 0
        spot.imageData = imageData
        spot.detailImagesData = detailImagesData.isEmpty ? nil : detailImagesData
        
        onSave()
    }
}