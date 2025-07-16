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
                
                Section(header: Text("メモ")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
                
                Section(header: Text("メイン画像")) {
                    if let imageData = imageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 200)
                            .cornerRadius(8)
                    }
                    
                    PhotosPicker(
                        selection: $selectedImage,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label("画像を選択", systemImage: "photo")
                    }
                }
                
                Section(header: Text("詳細画像（予約情報など）")) {
                    if !detailImagesData.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(Array(detailImagesData.enumerated()), id: \.offset) { index, data in
                                    if let uiImage = UIImage(data: data) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(height: 100)
                                            .cornerRadius(8)
                                            .overlay(alignment: .topTrailing) {
                                                Button(action: {
                                                    detailImagesData.remove(at: index)
                                                }) {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .foregroundColor(.red)
                                                        .background(Color.white.clipShape(Circle()))
                                                }
                                                .padding(4)
                                            }
                                    }
                                }
                            }
                        }
                    }
                    
                    PhotosPicker(
                        selection: $selectedDetailImages,
                        maxSelectionCount: 5,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label("詳細画像を追加", systemImage: "photo.on.rectangle.angled")
                    }
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
        .onChange(of: selectedImage) { newImage in
            Task {
                if let data = try? await newImage?.loadTransferable(type: Data.self) {
                    imageData = data
                }
            }
        }
        .onChange(of: selectedDetailImages) { newImages in
            Task {
                var newDetailImages: [Data] = []
                for item in newImages {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        newDetailImages.append(data)
                    }
                }
                if !newDetailImages.isEmpty {
                    detailImagesData.append(contentsOf: newDetailImages)
                }
                selectedDetailImages = []
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