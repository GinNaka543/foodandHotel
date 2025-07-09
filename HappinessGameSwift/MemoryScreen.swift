import SwiftUI
import PhotosUI
import AVKit

struct MemoryPhoto: Identifiable, Codable {
    let id: UUID
    let title: String
    let tags: [String]
    let imageData: Data
    let date: Date
    let filePath: String
}

struct MemoryScreen: View {
    @State private var photos: [MemoryPhoto] = []
    @State private var showingImagePicker = false
    @State private var showingAddPhoto = false
    @State private var selectedImage: UIImage?
    @State private var photoTitle = ""
    @State private var photoTags = ""
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(photos) { photo in
                        NavigationLink(destination: PhotoDetailView(photo: photo)) {
                            PhotoThumbnailView(photo: photo)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("メモリー")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddPhoto = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddPhoto) {
            AddPhotoView(
                selectedImage: $selectedImage,
                photoTitle: $photoTitle,
                photoTags: $photoTags,
                onSave: savePhoto
            )
        }
        .onAppear {
            loadPhotos()
        }
    }
    
    private func savePhoto() {
        guard let image = selectedImage,
              let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        
        let photo = MemoryPhoto(
            id: UUID(),
            title: photoTitle.isEmpty ? "無題" : photoTitle,
            tags: photoTags.isEmpty ? [] : photoTags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) },
            imageData: imageData,
            date: Date(),
            filePath: ""
        )
        
        photos.append(photo)
        savePhotosToStorage()
        
        // リセット
        selectedImage = nil
        photoTitle = ""
        photoTags = ""
        showingAddPhoto = false
    }
    
    private func loadPhotos() {
        // ローカルストレージから写真を読み込み
        // 実際の実装ではUserDefaultsやCore Dataを使用
    }
    
    private func savePhotosToStorage() {
        // ローカルストレージに写真を保存
        // 実際の実装ではUserDefaultsやCore Dataを使用
    }
}

struct PhotoThumbnailView: View {
    let photo: MemoryPhoto
    
    var body: some View {
        VStack {
            Image(uiImage: UIImage(data: photo.imageData) ?? UIImage())
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 150, height: 150)
                .clipped()
                .cornerRadius(12)
            
            Text(photo.title)
                .font(.caption)
                .lineLimit(1)
        }
    }
}

struct PhotoDetailView: View {
    let photo: MemoryPhoto
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(uiImage: UIImage(data: photo.imageData) ?? UIImage())
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(photo.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("撮影日: \(photo.date, style: .date)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !photo.tags.isEmpty {
                        Text("タグ: \(photo.tags.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .shadow(radius: 2)
            }
            .padding()
        }
        .navigationTitle("写真詳細")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    MemoryScreen()
} 