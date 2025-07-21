import SwiftUI
import AVKit
import PhotosUI
import Foundation
import UIKit
import AVFoundation

// VideoPlayerScreen is now properly imported from VideoPlayerScreen.swift

struct MemoryVideo: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let characterId: UUID
    let videoPath: String // 動画ファイルのパス
    var thumbnailData: Data?
    var title: String
    var tags: [String]
    let date: Date
    var youtubeURL: String? // YouTube URL
    var youtubeThumbnailURL: String? // YouTube サムネイルURL
}

struct Album: Identifiable, Hashable, Equatable, Codable {
    let id: UUID
    let tag: String
    let videos: [MemoryVideo]
    
    init(tag: String, videos: [MemoryVideo]) {
        self.id = UUID()
        self.tag = tag
        self.videos = videos
    }
    static func == (lhs: Album, rhs: Album) -> Bool {
        lhs.id == rhs.id && lhs.tag == rhs.tag && lhs.videos == rhs.videos
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(tag)
        hasher.combine(videos)
    }
}

struct VideoGalleryScreen: View {
    let character: Character
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var characterManager: CharacterManager
    @State private var videos: [MemoryVideo] = []
    @State private var showAddSheet = false
    @State private var selectedVideoURL: URL? = nil
    @State private var videoTitle: String = ""
    @State private var videoTags: String = ""
    @State private var showAlbum = false
    @State private var showAbout = false
    @State private var showTagInput = false
    @State private var newTag: String = ""
    @State private var filteredTags: [String] = []
    @State private var selectedVideo: MemoryVideo? = nil
    @State private var showEditTitle = false
    @State private var showEditTags = false
    @State private var editText = ""
    @State private var showThumbnailPicker = false
    @State private var isSelectingThumbnail = false
    @State private var activeAlert: ActiveAlert? = nil
    @State private var activeSheet: ActiveSheet? = nil
    
    // 最新のキャラクター情報を取得
    private var currentCharacter: Character {
        characterManager.characters.first(where: { $0.id == character.id }) ?? character
    }
    
    enum ActiveAlert: Identifiable {
        case deleteVideo(UUID)
        case deleteAlbum(Album)
        case youtubeError(String)
        
        var id: String {
            switch self {
            case .deleteVideo: return "deleteVideo"
            case .deleteAlbum: return "deleteAlbum"
            case .youtubeError: return "youtubeError"
            }
        }
    }
    
    enum ActiveSheet: Identifiable {
        case editTitle(MemoryVideo)
        case editTags(MemoryVideo)
        case thumbnailPicker(MemoryVideo)
        case videoDetail(MemoryVideo)
        case youtubeConfirmation(MemoryVideo)
        case tagInput
        
        var id: String {
            switch self {
            case .editTitle: return "editTitle"
            case .editTags: return "editTags"
            case .thumbnailPicker: return "thumbnailPicker"
            case .videoDetail: return "videoDetail"
            case .youtubeConfirmation: return "youtubeConfirmation"
            case .tagInput: return "tagInput"
            }
        }
    }
    @State private var selectedThumbnailData: Data? = nil
    @State private var expandedVideo: MemoryVideo? = nil
    @State private var playingVideoId: UUID? = nil
    @State private var albums: [Album] = []
    @State private var selectedAlbum: Album? = nil
    @State private var isDownloadingYouTube = false
    @State private var youtubeDownloadError: String? = nil
    @State private var isShowingFullDescription = false
    
    // ヘッダービュー
    var headerView: some View {
        HStack {
            // 戻るボタン（矢印）
            Button(action: { 
                dismiss() 
            }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.black)
                    .font(.system(size: 18, weight: .bold))
            }
            .buttonStyle(PlainButtonStyle())
            .frame(width: 60, alignment: .leading)
            
            Spacer()
            
            Spacer()
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8) // Reduced from 12 to 8
        .background(Color.white)
    }
    
    // バナービュー
    var bannerView: some View {
        Group {
            if let imageIdentifier = currentCharacter.imageIdentifier, let image = loadImageFromPath(imageIdentifier) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: 60)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(maxWidth: .infinity, maxHeight: 60)
            }
        }
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }
    
    // タブビュー
    var tabView: some View {
        HStack {
            HStack(spacing: 12) {
                Button(action: { showAlbum = false }) {
                    Text("Video")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(!showAlbum ? .white : .black)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(!showAlbum ? Color(.darkGray) : Color(.systemGray5))
                        )
                }
                
                Button(action: { showAlbum = true }) {
                    Text("Album")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(showAlbum ? .white : .black)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(showAlbum ? Color(.darkGray) : Color(.systemGray5))
                        )
                }
            }
            .padding(.leading, 16)
            Spacer()
        }
        .padding(.vertical, 8)
    }
    
    // コンテンツビュー
    var contentView: some View {
        ZStack {
            if showAlbum {
                albumView
            } else {
                videoListView
            }
        }
    }
    
    // アルバムビュー
    var albumView: some View {
        Group {
            if albums.isEmpty {
                VStack(spacing: 20) {
                Spacer()
                    .frame(maxHeight: 100)
                
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 60))
                    .foregroundColor(.purple)
                
                Text("まだアルバムがありません")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("同じタグのビデオからアルバムを作成できます")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button(action: {
                    activeSheet = .tagInput
                }) {
                    Label("アルバムを作成", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.purple)
                        .cornerRadius(25)
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(spacing: 4) {
                    Spacer().frame(height: 5)
                    ForEach(albums) { album in
                        Button(action: {
                            selectedAlbum = album
                        }) {
                            HStack(spacing: 12) {
                                // サムネイル
                                if let firstVideo = album.videos.first, let thumbnailData = firstVideo.thumbnailData, let uiImage = UIImage(data: thumbnailData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 160, height: 90)
                                        .clipped()
                                        .cornerRadius(8)
                                } else if let firstVideo = album.videos.first, let youtubeThumbnailURL = firstVideo.youtubeThumbnailURL {
                                    AsyncImage(url: URL(string: youtubeThumbnailURL)) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 160, height: 90)
                                            .clipped()
                                            .cornerRadius(8)
                                    } placeholder: {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 160, height: 90)
                                            .overlay(ProgressView())
                                    }
                                } else {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 160, height: 90)
                                }
                                
                                // 右側のコンテンツ
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("#" + album.tag)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.black)
                                    
                                    if let firstVideo = album.videos.first {
                                        Text(firstVideo.tags.isEmpty ? "タグなし" : firstVideo.tags.joined(separator: ", "))
                                            .font(.system(size: 14))
                                            .foregroundColor(.gray)
                                            .lineLimit(2)
                                    }
                                    
                                    Text("\(album.videos.count)件")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                // 3点ボタン
                                Button(action: {
                                    activeAlert = .deleteAlbum(album)
                                }) {
                                    Image(systemName: "ellipsis")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 32, height: 32)
                                        .background(Color.black.opacity(0.7))
                                        .clipShape(Circle())
                                        .shadow(radius: 4)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                            .background(Color.white)
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                }
            }
            }
        }
        .fullScreenCover(item: $selectedAlbum) { album in
            AlbumVideoListScreen(
                videos: album.videos, 
                tag: album.tag,
                onVideoDeleted: { deletedVideo in
                    if let idx = videos.firstIndex(where: { $0.id == deletedVideo.id }) {
                        videos.remove(at: idx)
                        updateAlbumsAfterVideoDeletion(deletedVideoId: deletedVideo.id)
                        saveVideosToUserDefaults()
                        saveAlbumsToUserDefaults()
                    }
                }
            )
        }
    }
    
    // ビデオリストビュー
    var videoListView: some View {
        Group {
            if videos.isEmpty {
                VStack(spacing: 20) {
                    Spacer()
                        .frame(maxHeight: 100)
                    
                    Image(systemName: "video.slash")
                        .font(.system(size: 60))
                        .foregroundColor(.purple)
                    
                    Text("まだビデオがありません")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("右上の追加ボタンからビデオを追加できます")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button(action: {
                        showAddSheet = true
                    }) {
                        Label("ビデオを追加", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.purple)
                            .cornerRadius(25)
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer().frame(height: 5)
                        ForEach(Array(videos.enumerated()), id: \.element.id) { idx, video in
                            if idx > 0 {
                                Spacer().frame(height: 35)
                            }
                            videoRowView(video: video)
                        }
                    }
                }
            }
        }
        .fullScreenCover(item: $selectedVideo) { video in
            VideoPlayerScreen(
                video: video,
                character: character as Character?,
                anime: nil as Anime?,
                allVideos: videos,
                onSave: { newTitle, newTags in
                    if let idx = videos.firstIndex(where: { $0.id == video.id }) {
                        var updated = videos[idx]
                        updated.title = newTitle
                        updated.tags = newTags
                        videos[idx] = updated
                        saveVideosToUserDefaults()
                    }
                },
                onDelete: {
                    deleteVideo(id: video.id)
                    selectedVideo = nil
                },
                onThumbnailUpdate: { newThumbnailData in
                    if let idx = videos.firstIndex(where: { $0.id == video.id }) {
                        var updated = videos[idx]
                        updated.thumbnailData = newThumbnailData
                        videos[idx] = updated
                        saveVideosToUserDefaults()
                    }
                }
            )
        }
    }
    
    // ビデオ行ビュー
    func videoRowView(video: MemoryVideo) -> some View {
        Button(action: {
            // YouTube動画の場合は確認ページを表示
            if let youtubeURL = video.youtubeURL, !youtubeURL.isEmpty {
                activeSheet = .youtubeConfirmation(video)
            } else {
                selectedVideo = video
            }
        }) {
            HStack(alignment: .top, spacing: 16) {
                // サムネイル
                if let thumbnailData = video.thumbnailData, let uiImage = UIImage(data: thumbnailData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 160, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .clipped()
                } else if let youtubeThumbnailURL = video.youtubeThumbnailURL {
                    AsyncImage(url: URL(string: youtubeThumbnailURL)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 160, height: 90)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .clipped()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 160, height: 90)
                            .overlay(ProgressView())
                    }
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 160, height: 90)
                }
                
                // タイトルとタグ
                VStack(alignment: .leading, spacing: 4) {
                    Text(video.title)
                        .font(.system(size: 16.5, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.vertical, 8)
                    Text(video.tags.isEmpty ? "#nakajimaginsei" : "#" + video.tags.joined(separator: " #"))
                        .font(.system(size: 13.8, weight: .regular))
                        .foregroundColor(.gray)
                        .padding(.vertical, 2)
                }
                .frame(height: 50, alignment: .leading)
                .padding(.top, 3)
                .padding(.leading, 8)
                
                Spacer()
                
                // メニューボタン
                Menu {
                    Button(action: {
                        editText = video.title
                        activeSheet = .editTitle(video)
                    }) {
                        Label("タイトルを編集", systemImage: "pencil")
                    }
                    Button(action: {
                        editText = video.tags.joined(separator: ", ")
                        activeSheet = .editTags(video)
                    }) {
                        Label("タグを編集", systemImage: "tag")
                    }
                    Button(action: {
                        activeSheet = .thumbnailPicker(video)
                    }) {
                        Label("サムネイルを変更", systemImage: "photo")
                    }
                    Divider()
                    Button(role: .destructive, action: {
                        print("[DEBUG] 削除ボタンが押されました - Video ID: \(video.id)")
                        activeAlert = .deleteVideo(video.id)
                        print("[DEBUG] activeAlert set to deleteVideo")
                    }) {
                        Label("削除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18))
                        .foregroundColor(.gray)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Circle())
                }
                .padding(.trailing, 8)
            }
            .padding(.leading, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }

    @ViewBuilder
    private var profileSection: some View {
        HStack(spacing: 12) {
            // Character icon
            if let imageIdentifier = currentCharacter.imageIdentifier, let image = loadImageFromPath(imageIdentifier) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 67, height: 67)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 67, height: 67)
                    .overlay(
                        Image(systemName: "person")
                            .font(.system(size: 33))
                            .foregroundColor(.gray)
                    )
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(currentCharacter.name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.black)
                Text("@\(currentCharacter.name)")
                    .font(.system(size: 12.7))
                    .foregroundColor(.black)
                Text("\(videos.count)本の動画・アルバム数\(albums.count)")
                    .font(.system(size: 15.4))
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    @ViewBuilder
    private var descriptionSection: some View {
        if let customFields = currentCharacter.customFields,
           let descriptionField = customFields.first(where: { $0.name == "概要" }),
           !descriptionField.value.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                if descriptionField.value.count > 13 && !isShowingFullDescription {
                    HStack(spacing: 0) {
                        Text(String(descriptionField.value.prefix(13)) + "... ")
                            .font(.system(size: 14))
                            .foregroundColor(.black)
                        Text("さらに表示")
                            .font(.system(size: 14))
                            .foregroundColor(.black)
                            .underline()
                            .onTapGesture {
                                isShowingFullDescription = true
                            }
                    }
                } else {
                    Text(descriptionField.value)
                        .font(.system(size: 14))
                        .foregroundColor(.black)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    if descriptionField.value.count > 13 {
                        Text(" 折りたたむ")
                            .font(.system(size: 14))
                            .foregroundColor(.black)
                            .underline()
                            .onTapGesture {
                                isShowingFullDescription = false
                            }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 16)
            .padding(.trailing, 16)
            .padding(.bottom, 12)
        }
    }
    
    @ViewBuilder
    private var navigationBar: some View {
        VStack {
            Spacer()
            HStack(spacing: 0) {
                // Back button
                Button(action: {
                    dismiss()
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 24))
                        Text("戻る")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(VideoNavigationButtonStyle())
                
                // Video button
                Button(action: {
                    showAlbum = false
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "video")
                            .font(.system(size: 24))
                        Text("Video")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(!showAlbum ? .black : .gray)
                    .frame(maxWidth: .infinity)
                }
                
                // Album button
                Button(action: {
                    showAlbum = true
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "rectangle.grid.2x2")
                            .font(.system(size: 24))
                        Text("Album")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(showAlbum ? .black : .gray)
                    .frame(maxWidth: .infinity)
                }
                
                // About button
                Button(action: {
                    showAbout = true
                }) {
                    VStack(spacing: 4) {
                        if let imageIdentifier = currentCharacter.imageIdentifier, 
                           let image = loadImageFromPath(imageIdentifier) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 24, height: 24)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle")
                                .font(.system(size: 24))
                        }
                        Text("About")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 8)
            .background(Color.white)
            .overlay(
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 0.5),
                alignment: .top
            )
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 0) {
                    // Banner (no header)
                    bannerView
                        .allowsHitTesting(false) // バナーのタップを無効化
                        .zIndex(1)
                    
                    // Profile section
                    profileSection
                    
                    // Description section
                    descriptionSection
                    
                    // Add button moved here
                    Button(action: { 
                        videoTitle = ""
                        videoTags = ""
                        showAddSheet = true 
                    }) {
                        Text("動画を追加する")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10.4)  // 12 / 1.15 = 10.4
                            .background(Color.black)
                            .cornerRadius(20)
                    }
                    .padding(.horizontal, 16)  // Same as banner padding
                    .padding(.bottom, 16)
                    
                    // Tab view
                    tabView
                    
                    // Content view
                    contentView
                }
            }
            floatingButton
            
            // Navigation bar at bottom
            navigationBar
        }
        .overlay(loadingOverlay)
        .onAppear {
            loadVideos()
            loadAlbumsFromUserDefaults()
        }
        .fullScreenCover(isPresented: $showAbout) {
            AboutView(characters: $characterManager.characters, characterId: character.id, onClose: { showAbout = false })
                .environmentObject(characterManager)
        }
        .sheet(isPresented: $showAddSheet) {
            AddVideoView(
                selectedVideoURL: $selectedVideoURL,
                videoTitle: $videoTitle,
                videoTags: $videoTags,
                selectedThumbnailData: $selectedThumbnailData,
                onSave: {
                    if selectedVideoURL != nil && !videoTitle.trimmingCharacters(in: .whitespaces).isEmpty && !videoTags.trimmingCharacters(in: .whitespaces).isEmpty {
                        Task {
                            await saveVideo()
                        }
                    }
                },
                onYouTubeSave: { url, title, thumbnailURL, tags in
                    saveYouTubeVideo(url: url, title: title, thumbnailURL: thumbnailURL, tags: tags)
                }
            )
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .editTitle(let video):
                editTitleSheet(video: video)
            case .editTags(let video):
                editTagsSheet(video: video)
            case .thumbnailPicker(let video):
                ThumbnailPickerView(
                    video: video,
                    onSave: { newThumbnailData in
                        if let idx = videos.firstIndex(where: { $0.id == video.id }) {
                            var updated = videos[idx]
                            updated.thumbnailData = newThumbnailData
                            videos[idx] = updated
                            saveVideosToUserDefaults()
                        }
                        activeSheet = nil
                    },
                    onCancel: {
                        activeSheet = nil
                    }
                )
            case .videoDetail(let video):
                videoDetailSheet(video: video)
            case .youtubeConfirmation(let video):
                youtubeConfirmationSheet(video: video)
            case .tagInput:
                tagInputSheet
            }
        }
        .alert(item: $activeAlert) { alertType in
            switch alertType {
            case .deleteVideo(let videoId):
                print("[DEBUG] 削除アラートが表示されようとしています - Video ID: \(videoId)")
                return Alert(
                    title: Text("動画を削除しますか？"),
                    message: Text("この動画は完全に削除されます。"),
                    primaryButton: .destructive(Text("削除")) {
                        print("[DEBUG] 削除確認アラートの削除ボタンが押されました")
                        print("[DEBUG] Video ID: \(videoId)")
                        deleteVideo(id: videoId)
                        print("[DEBUG] 削除処理完了")
                    },
                    secondaryButton: .cancel(Text("キャンセル")) {
                        print("[DEBUG] 削除キャンセルボタンが押されました")
                    }
                )
            case .deleteAlbum(let album):
                return Alert(
                    title: Text("アルバムを削除しますか？"),
                    message: Text("このアルバムは完全に削除されます。"),
                    primaryButton: .destructive(Text("削除")) {
                        deleteAlbum(album)
                    },
                    secondaryButton: .cancel(Text("キャンセル"))
                )
            case .youtubeError(let message):
                return Alert(
                    title: Text("YouTubeダウンロードエラー"),
                    message: Text(message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    // メインコンテンツ
    
    // フローティングボタン
    var floatingButton: some View {
        Group {
            if showAlbum && !albums.isEmpty {
                Button(action: { showTagInput = true }) {
                    Text("#")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.black)
                        .clipShape(Circle())
                        .shadow(radius: 6)
                        .padding(.bottom, 32)
                        .padding(.trailing, 24)
                }
                .sheet(isPresented: $showTagInput) {
                    tagInputSheet
                }
            }
        }
    }
    
    // タグ入力シート
    var tagInputSheet: some View {
        VStack(spacing: 24) {
            Text("同じタグからアルバムを作れます")
                .font(.headline)
            TextField("#タグ名", text: $newTag)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal, 24)
            Button("保存") {
                let tag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
                if !tag.isEmpty {
                    let tagVideos = videos.filter { $0.tags.contains(where: { $0 == tag }) }
                    if !tagVideos.isEmpty {
                        albums.append(Album(tag: tag, videos: tagVideos))
                        saveAlbumsToUserDefaults()
                    }
                }
                newTag = ""
                activeSheet = nil
                showTagInput = false
            }
            .font(.headline)
            .padding(.horizontal, 32)
            .padding(.vertical, 10)
            .background(Color.black)
            .foregroundColor(.white)
            .cornerRadius(10)
            Button("キャンセル") {
                activeSheet = nil
                showTagInput = false
            }
            .foregroundColor(.red)
        }
        .padding(32)
    }
    
    // タイトル編集シート
    func editTitleSheet(video: MemoryVideo) -> some View {
        VStack(spacing: 24) {
            Text("タイトルを編集")
                .font(.headline)
                .padding(.top, 24)
            
            TextField("タイトル", text: $editText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.system(size: 18))
                .padding(.horizontal, 24)
            
            HStack(spacing: 24) {
                Button(action: {
                    activeSheet = nil
                }) {
                    Text("キャンセル")
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
                
                Button(action: {
                    if let idx = videos.firstIndex(where: { $0.id == video.id }) {
                        var updated = videos[idx]
                        updated.title = editText
                        videos[idx] = updated
                        saveVideosToUserDefaults()
                    }
                    activeSheet = nil
                }) {
                    Text("保存")
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.black)
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Color.white)
        .cornerRadius(20)
        .shadow(radius: 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.3))
        .edgesIgnoringSafeArea(.all)
    }
    
    // タグ編集シート
    func editTagsSheet(video: MemoryVideo) -> some View {
        VStack(spacing: 24) {
            Text("タグを編集")
                .font(.headline)
                .padding(.top, 24)
            
            TextField("タグ（カンマ区切り）", text: $editText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.system(size: 18))
                .padding(.horizontal, 24)
            
            HStack(spacing: 24) {
                Button(action: {
                    activeSheet = nil
                }) {
                    Text("キャンセル")
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
                
                Button(action: {
                    if let idx = videos.firstIndex(where: { $0.id == video.id }) {
                        var updated = videos[idx]
                        updated.tags = editText.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                        videos[idx] = updated
                        saveVideosToUserDefaults()
                    }
                    activeSheet = nil
                }) {
                    Text("保存")
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.black)
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Color.white)
        .cornerRadius(20)
        .shadow(radius: 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.3))
        .edgesIgnoringSafeArea(.all)
    }
    
    // ローディングオーバーレイ
    var loadingOverlay: some View {
        Group {
            if isDownloadingYouTube {
                ZStack {
                    Color.black.opacity(0.5).ignoresSafeArea()
                    VStack(spacing: 24) {
                        ProgressView()
                            .scaleEffect(2)
                        Text("YouTube動画をダウンロード中…")
                            .font(.title2)
                            .foregroundColor(.white)
                            .bold()
                    }
                    .padding(40)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(20)
                }
            }
        }
    }
    
    // ビデオ詳細シート
    func videoDetailSheet(video: MemoryVideo) -> some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 24) {
                Spacer()
                VideoThumbnailPlayer(video: video, isInModal: true, onTap: {})
                    .frame(maxWidth: .infinity, minHeight: (UIScreen.main.bounds.width) * 9 / 16, maxHeight: (UIScreen.main.bounds.width) * 9 / 16)
                    .cornerRadius(0)
                videoInfoView(video: video)
                Spacer()
            }
            videoDetailButtons(video: video)
            videoDetailDialogs(video: video)
        }
        .sheet(isPresented: $showThumbnailPicker) {
            ThumbnailPickerView(
                video: selectedVideo ?? videos[0],
                onSave: { newThumbnailData in
                    if let selectedVideo = selectedVideo,
                       let idx = videos.firstIndex(where: { $0.id == selectedVideo.id }) {
                        var updated = videos[idx]
                        updated.thumbnailData = newThumbnailData
                        videos[idx] = updated
                        saveVideosToUserDefaults()
                    }
                    showThumbnailPicker = false
                },
                onCancel: {
                    showThumbnailPicker = false
                }
            )
        }
    }
    
    // YouTube確認ページ
    func youtubeConfirmationSheet(video: MemoryVideo) -> some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 20) {
                // サムネイル
                if let thumbnailData = video.thumbnailData, let uiImage = UIImage(data: thumbnailData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 300)
                        .cornerRadius(12)
                } else if let thumbnailURL = video.youtubeThumbnailURL {
                    AsyncImage(url: URL(string: thumbnailURL)) { image in
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: 300)
                            .cornerRadius(12)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 200)
                            .overlay(ProgressView())
                    }
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 200)
                }
                
                Text(video.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button(action: {
                    if let youtubeURL = video.youtubeURL, let url = URL(string: youtubeURL) {
                        UIApplication.shared.open(url)
                    }
                    activeSheet = nil
                }) {
                    HStack {
                        Image(systemName: "play.circle.fill")
                            .font(.title)
                        Text("YouTubeで開く")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.red)
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                Button(action: {
                    activeSheet = nil
                }) {
                    Text("閉じる")
                        .foregroundColor(.gray)
                        .padding()
                }
            }
            
            Spacer()
        }
        .background(Color(.systemBackground))
    }
    
    // ビデオ情報ビュー
    func videoInfoView(video: MemoryVideo) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                Text("タイトル: \(video.title)")
                    .font(.headline)
                Button(action: {
                    editText = video.title
                    showEditTitle = true
                }) {
                    Image(systemName: "pencil")
                        .foregroundColor(.blue)
                }
            }
            HStack(spacing: 8) {
                Text("タグ: \(video.tags.joined(separator: ", "))")
                    .font(.subheadline)
                Button(action: {
                    editText = video.tags.joined(separator: ",")
                    showEditTags = true
                }) {
                    Image(systemName: "pencil")
                        .foregroundColor(.blue)
                }
            }
            Text("ID: \(video.id.uuidString.prefix(8))")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
    
    // ビデオ詳細ボタン
    func videoDetailButtons(video: MemoryVideo) -> some View {
        Group {
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        expandedVideo = nil
                    }) {
                        Text("閉じる")
                            .font(.headline)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color(.systemGray6))
                            .cornerRadius(20)
                    }
                    Spacer()
                }
                .padding(.bottom, 24)
                .padding(.leading, 42)
            }
            Button(action: {
                activeAlert = .deleteVideo(video.id)
            }) {
                ZStack {
                    Color.clear
                    Image(systemName: "trash")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .foregroundColor(.black)
                }
                .frame(width: 44, height: 44)
            }
            .padding(.bottom, 24)
            .padding(.trailing, 24)
        }
    }
    
    // ビデオ詳細ダイアログ
    func videoDetailDialogs(video: MemoryVideo) -> some View {
        Group {
            if showEditTitle {
                editTitleDialog(video: video)
            }
            if showEditTags {
                editTagsDialog(video: video)
            }
        }
    }
    
    // タイトル編集ダイアログ
    func editTitleDialog(video: MemoryVideo) -> some View {
        ZStack {
            Color.black.opacity(0.25)
                .edgesIgnoringSafeArea(.all)
            VStack(spacing: 20) {
                Text("タイトル名を編集")
                    .font(.headline)
                    .padding(.top, 12)
                TextField("タイトル", text: $editText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 18))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                HStack(spacing: 24) {
                    Button(action: { showEditTitle = false }) {
                        Text("キャンセル")
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    Button(action: {
                        if let idx = videos.firstIndex(where: { $0.id == video.id }) {
                            var updated = videos[idx]
                            updated.title = editText
                            videos[idx] = updated
                            saveVideosToUserDefaults()
                        }
                        showEditTitle = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            expandedVideo = nil
                        }
                    }) {
                        Text("保存")
                            .foregroundColor(.blue)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .background(Color.white)
            .cornerRadius(18)
            .shadow(radius: 16)
            .frame(maxWidth: 340)
            .padding(.horizontal, 32)
        }
    }
    
    // タグ編集ダイアログ
    func editTagsDialog(video: MemoryVideo) -> some View {
        ZStack {
            Color.black.opacity(0.25)
                .edgesIgnoringSafeArea(.all)
            VStack(spacing: 20) {
                Text("タグを編集")
                    .font(.headline)
                    .padding(.top, 12)
                TextField("タグ（カンマ区切り）", text: $editText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 18))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                HStack(spacing: 24) {
                    Button(action: { showEditTags = false }) {
                        Text("キャンセル")
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    Button(action: {
                        if let idx = videos.firstIndex(where: { $0.id == video.id }) {
                            var updated = videos[idx]
                            updated.tags = editText.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                            videos[idx] = updated
                            saveVideosToUserDefaults()
                        }
                        showEditTags = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            expandedVideo = nil
                        }
                    }) {
                        Text("保存")
                            .foregroundColor(.blue)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .background(Color.white)
            .cornerRadius(18)
            .shadow(radius: 16)
            .frame(maxWidth: 340)
            .padding(.horizontal, 32)
        }
    }
    
    // 削除確認ダイアログ
    
    private func saveVideo() async {
        guard let videoURL = selectedVideoURL else { return }
        let tags = videoTags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        
        // 動画ファイルをDocumentsディレクトリに保存
        let fileName = "video_\(UUID().uuidString).mov"
        let documentsPath = saveVideoToDocuments(from: videoURL, fileName: fileName)
        
        // サムネイル生成
        var thumbnailData: Data? = selectedThumbnailData
        if thumbnailData == nil {
            let asset = AVURLAsset(url: videoURL)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            
            do {
                let cgImage = try await imageGenerator.image(at: CMTime(seconds: 1.0, preferredTimescale: 1))
                let uiImage = UIImage(cgImage: cgImage.image)
                thumbnailData = uiImage.jpegData(compressionQuality: 0.8)
            } catch {
                print("サムネイル生成に失敗: \(error)")
            }
        }
        
        let newVideo = MemoryVideo(id: UUID(), characterId: character.id, videoPath: documentsPath, thumbnailData: thumbnailData, title: videoTitle, tags: tags, date: Date(), youtubeURL: nil, youtubeThumbnailURL: nil)
        videos.insert(newVideo, at: 0)
        saveVideosToUserDefaults()
        selectedVideoURL = nil
        videoTitle = ""
        videoTags = ""
        selectedThumbnailData = nil
        showAddSheet = false
    }
    
    private func saveVideoToDocuments(from url: URL, fileName: String) -> String {
        let fileManager = FileManager.default
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        guard let documentsURL = urls.first else { return "" }
        
        // アプリ専用のサブディレクトリを作成
        let appDirectoryURL = documentsURL.appendingPathComponent("AnirecoImages")
        
        do {
            // ディレクトリが存在しない場合は作成
            if !fileManager.fileExists(atPath: appDirectoryURL.path) {
                try fileManager.createDirectory(at: appDirectoryURL, withIntermediateDirectories: true, attributes: nil)
            }
            
            let fileURL = appDirectoryURL.appendingPathComponent(fileName)
            
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
            try fileManager.copyItem(at: url, to: fileURL)
            return "AnirecoImages/\(fileName)"
        } catch {
            print("動画保存エラー: \(error)")
            return ""
        }
    }
    
    private func loadVideos() {
        let key = "videos_\(character.id.uuidString)"
        if let data = UserDefaults.standard.data(forKey: key),
           let decodedVideos = try? JSONDecoder().decode([MemoryVideo].self, from: data) {
            videos = decodedVideos
        }
    }
    
    private func saveVideosToUserDefaults() {
        let key = "videos_\(character.id.uuidString)"
        if let encodedData = try? JSONEncoder().encode(videos) {
            UserDefaults.standard.set(encodedData, forKey: key)
            print("VideoGalleryScreen: UserDefaults保存完了 - 動画数: \(videos.count)")
        }
    }
    
    private func saveAlbumsToUserDefaults() {
        let key = "video_albums_\(character.id.uuidString)"
        if let encodedData = try? JSONEncoder().encode(albums) {
            UserDefaults.standard.set(encodedData, forKey: key)
            print("[DEBUG] VideoGalleryScreen: アルバムをUserDefaultsに保存しました")
        }
    }
    
    private func loadAlbumsFromUserDefaults() {
        let key = "video_albums_\(character.id.uuidString)"
        if let data = UserDefaults.standard.data(forKey: key),
           let decodedAlbums = try? JSONDecoder().decode([Album].self, from: data) {
            albums = decodedAlbums
            print("[DEBUG] VideoGalleryScreen: アルバムをUserDefaultsから読み込みました - 件数: \(albums.count)")
        }
    }
    
    private func deleteVideo(id: UUID) {
        print("[DEBUG] deleteVideo called with ID: \(id)")
        print("[DEBUG] Current videos count: \(videos.count)")
        if let idx = videos.firstIndex(where: { $0.id == id }) {
            print("[DEBUG] Found video at index: \(idx)")
            videos.remove(at: idx)
            print("[DEBUG] After removal, videos count: \(videos.count)")
            print("VideoAlbumGridView: 動画削除 - ID: \(id)")
            updateAlbumsAfterVideoDeletion(deletedVideoId: id)
            saveVideosToUserDefaults()
            saveAlbumsToUserDefaults()
            print("[DEBUG] Delete process completed")
        } else {
            print("[DEBUG] Video with ID \(id) not found in videos array")
        }
    }
    
    private func updateAlbumsAfterVideoDeletion(deletedVideoId: UUID) {
        // 各Albumから削除された動画を除去
        albums = albums.compactMap { album in
            let updatedVideos = album.videos.filter { $0.id != deletedVideoId }
            // 動画が1つも残っていない場合はAlbumを削除
            if updatedVideos.isEmpty {
                return nil
            }
            // 動画が残っている場合は更新されたAlbumを返す
            return Album(tag: album.tag, videos: updatedVideos)
        }
        print("[DEBUG] VideoGalleryScreen: Album更新完了 - 残りAlbum数: \(albums.count)")
    }
    
    private func deleteAlbum(_ album: Album) {
        if let index = albums.firstIndex(where: { $0.id == album.id }) {
            albums.remove(at: index)
            saveAlbumsToUserDefaults()
            print("[DEBUG] VideoGalleryScreen: アルバム削除完了 - 残りAlbum数: \(albums.count)")
        }
    }
    
    private func saveYouTubeVideo(url: String, title: String, thumbnailURL: String, tags: String) {
        let tagArray = tags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        
        // YouTube動画の場合はvideoPathは空文字列にする
        let newVideo = MemoryVideo(
            id: UUID(),
            characterId: character.id,
            videoPath: "",
            thumbnailData: selectedThumbnailData, // カスタムサムネイルデータを使用
            title: title,
            tags: tagArray,
            date: Date(),
            youtubeURL: url,
            youtubeThumbnailURL: thumbnailURL == "custom" ? nil : thumbnailURL // customの場合はnilにする
        )
        
        videos.insert(newVideo, at: 0)
        saveVideosToUserDefaults()
        selectedThumbnailData = nil // リセット
        showAddSheet = false
    }
    
    private func downloadYouTubeVideo(youtubeURL: String) async throws -> URL {
        let apiKey = "eed595d1demsh4ffce2821e5cd5ap1eac28jsn0896c171f935"
        let encodedURL = youtubeURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? youtubeURL
        let apiURLString = "https://youtube-info-download-api.p.rapidapi.com/ajax/download.php?format=mp4&add_info=0&url=\(encodedURL)&audio_quality=128&allow_extended_duration=false"
        guard let apiURL = URL(string: apiURLString) else {
            throw NSError(domain: "URL生成エラー", code: 0)
        }
        var request = URLRequest(url: apiURL)
        request.httpMethod = "GET"
        request.setValue("youtube-info-download-api.p.rapidapi.com", forHTTPHeaderField: "x-rapidapi-host")
        request.setValue(apiKey, forHTTPHeaderField: "x-rapidapi-key")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "APIリクエスト失敗", code: 0)
        }
        // --- レスポンス内容をprintで出力 ---
        if let jsonString = String(data: data, encoding: .utf8) {
            print("[YouTube APIレスポンス]", jsonString)
        }
        // 2. レスポンスからダウンロードリンクを抽出（仮にJSONで { "link": "..." } 形式とする）
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let downloadLink = json["link"] as? String,
              let videoDownloadURL = URL(string: downloadLink) else {
            throw NSError(domain: "ダウンロードリンク取得失敗", code: 0)
        }
        // 3. 動画ファイルをダウンロード
        let (videoData, _) = try await URLSession.shared.data(from: videoDownloadURL)
        // 4. 一時ファイルに保存
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        try videoData.write(to: tempURL)
        return tempURL
    }
}

struct VideoThumbnailPlayer: View {
    let video: MemoryVideo
    var isInModal: Bool = false // モーダル内かどうか
    @State private var player: AVPlayer? = nil
    @State private var tempURL: URL? = nil
    @State private var isPlaying = false
    var onTap: (() -> Void)? = nil // タップ時のコールバック
    
    var body: some View {
        ZStack {
            if isInModal, let player = player, isPlaying {
                VideoPlayer(player: player)
                    .onTapGesture {
                        player.pause()
                        isPlaying = false
                    }
            } else {
                // サムネイル表示
                if let thumbnailData = video.thumbnailData,
                   let uiImage = UIImage(data: thumbnailData) {
                    GeometryReader { geometry in
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: 233)
                            .clipped()
                    }
                    .frame(height: 233)
                    .onTapGesture {
                        if isInModal {
                            playVideo()
                        } else {
                            onTap?()
                        }
                    }
                } else if let youtubeThumbnailURL = video.youtubeThumbnailURL {
                    GeometryReader { geometry in
                        AsyncImage(url: URL(string: youtubeThumbnailURL)) { image in
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: geometry.size.width, height: 233)
                                .clipped()
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 0, style: .continuous)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: geometry.size.width, height: 233)
                                .overlay(ProgressView())
                        }
                    }
                    .frame(height: 233)
                    .onTapGesture {
                        if isInModal {
                            playVideo()
                        } else {
                            onTap?()
                        }
                    }
                } else {
                    GeometryReader { geometry in
                        RoundedRectangle(cornerRadius: 0, style: .continuous)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: geometry.size.width, height: 233)
                    }
                    .frame(height: 233)
                    .onTapGesture {
                        if isInModal {
                            playVideo()
                        } else {
                            onTap?()
                        }
                    }
                }
            }
        }
        .onAppear {
            if player == nil && video.youtubeURL == nil && !video.videoPath.isEmpty {
                // videoPathから動画ファイルを読み込む
                if let videoURL = loadVideoURLFromPath(video.videoPath) {
                    player = AVPlayer(url: videoURL)
                }
            }
        }
        .onDisappear {
            player?.pause()
            isPlaying = false
            // 一時ファイル削除
            if let url = tempURL {
                try? FileManager.default.removeItem(at: url)
                tempURL = nil
            }
        }
    }
    
    private func playVideo() {
        guard let player = player else { return }
        player.seek(to: .zero)
        player.play()
        isPlaying = true
    }
}

struct VideoAlbumGridView: View {
    @Binding var videos: [MemoryVideo]
    let highlightFirstRow: Bool
    let filteredTags: [String]?
    var onVideoTap: ((MemoryVideo) -> Void)? = nil
    var onVideosChanged: (() -> Void)? = nil
    @State private var expandedVideo: MemoryVideo? = nil // 拡大用
    @State private var showEditTitle: Bool = false
    @State private var showEditTags: Bool = false
    @State private var editText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 1行目: 全動画
            if !videos.isEmpty {
                ForEach(videos) { video in
                    HStack(alignment: .center, spacing: 16) {
                        if let thumbnailData = video.thumbnailData, let uiImage = UIImage(data: thumbnailData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 176, height: 106)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .clipped()
                        } else if let youtubeThumbnailURL = video.youtubeThumbnailURL {
                            AsyncImage(url: URL(string: youtubeThumbnailURL)) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 176, height: 106)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .clipped()
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 176, height: 106)
                                    .overlay(ProgressView())
                            }
                        } else {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 176, height: 106)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(video.title)
                                .font(.system(size: 16.5, weight: .semibold))
                                .foregroundColor(.black)
                            Text(video.tags.isEmpty ? "#nakajimaginsei" : "#" + video.tags.joined(separator: " #"))
                                .font(.system(size: 13.8, weight: .regular))
                                .foregroundColor(.gray)
                        }
                        .frame(height: 50, alignment: .leading)
                        .padding(.top, 3)
                        .padding(.leading, 8)
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
            }
            // 2行目以降: タグごとのグループ
            if let tags = filteredTags {
                ForEach(tags, id: \.self) { tag in
                    let tagVideos = videos.filter { $0.tags.contains(tag) }
                    if !tagVideos.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("#" + tag)
                                .font(.headline)
                                .padding(.leading, 16)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 24) {
                                    ForEach(tagVideos) { video in
                                        VideoThumbnailPlayer(video: video, isInModal: false, onTap: {
                                            expandedVideo = video
                                        })
                                            .frame(width: 187, height: 112)
                                            .cornerRadius(20)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                }
            }
        }
        .fullScreenCover(item: $expandedVideo) { (video: MemoryVideo) in
            VideoPlayerScreen(
                video: video,
                character: nil as Character?,
                anime: nil as Anime?,
                allVideos: videos
            )
        }
    }
    
    private func deleteVideo(id: UUID) {
        if let idx = videos.firstIndex(where: { $0.id == id }) {
            videos.remove(at: idx)
            print("VideoAlbumGridView: 動画削除 - ID: \(id)")
            onVideosChanged?()
        }
    }
}

// Videoタブ用のインライン再生View
struct VideoInlinePlayer: View {
    let video: MemoryVideo
    let onClose: () -> Void
    @State private var player: AVPlayer? = nil
    @State private var isPlaying: Bool = true
    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let player = player {
                VideoPlayer(player: player)
                    .onDisappear {
                        player.pause()
                    }
            } else {
                Color.black
            }
            Button(action: {
                player?.pause()
                onClose()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .resizable()
                    .frame(width: 32, height: 32)
                    .foregroundColor(.white)
                    .shadow(radius: 4)
                    .padding(8)
            }
        }
        .onAppear {
            if let videoURL = loadVideoURLFromPath(video.videoPath) {
                player = AVPlayer(url: videoURL)
            }
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}

// キャラアイコン表示用のView
struct CharacterIconView: View {
    let imagePath: String?
    var size: CGFloat = 40
    var body: some View {
        if let imagePath = imagePath, let image = UIImage(contentsOfFile: imagePath) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "person")
                        .font(.system(size: size / 2))
                        .foregroundColor(.gray)
                )
        }
    }
}

// --- アルバムの動画一覧ページ ---
struct AlbumVideoListScreen: View {
    let videos: [MemoryVideo]
    let tag: String
    let onVideoDeleted: ((MemoryVideo) -> Void)?
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedVideo: MemoryVideo? = nil
    var body: some View {
        VStack(spacing: 0) {
            // アルバムバナー
            if let firstVideo = videos.first {
                ZStack(alignment: .bottomLeading) {
                    // バナー背景画像
                    Group {
                        if let thumbnailData = firstVideo.thumbnailData, let uiImage = UIImage(data: thumbnailData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                        } else if let youtubeThumbnailURL = firstVideo.youtubeThumbnailURL {
                            AsyncImage(url: URL(string: youtubeThumbnailURL)) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                            }
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                        }
                    }
                    .frame(height: 180)
                    .clipped()
                    .overlay(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.black.opacity(0.6), Color.black.opacity(0)]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    
                    // アルバム情報
                    VStack(alignment: .leading, spacing: 4) {
                        Text("#" + tag)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        Text("\(videos.count)件の動画")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            HStack {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.black)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            Spacer().frame(height: 15)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(videos.enumerated()), id: \ .element.id) { idx, video in
                        if idx > 0 {
                            Spacer().frame(height: 35)
                        }
                        Button(action: {
                            selectedVideo = video
                        }) {
                            HStack(alignment: .top, spacing: 16) {
                                if let thumbnailData = video.thumbnailData, let uiImage = UIImage(data: thumbnailData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 160, height: 90)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                        .clipped()
                                } else if let youtubeThumbnailURL = video.youtubeThumbnailURL {
                                    AsyncImage(url: URL(string: youtubeThumbnailURL)) { image in
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 160, height: 90)
                                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                            .clipped()
                                    } placeholder: {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 160, height: 90)
                                            .overlay(
                                                ProgressView()
                                            )
                                    }
                                } else {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 160, height: 90)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(video.title)
                                        .font(.system(size: 16.5, weight: .semibold))
                                        .foregroundColor(.black)
                                    Text(video.tags.isEmpty ? "#nakajimaginsei" : "#" + video.tags.joined(separator: " #"))
                                        .font(.system(size: 13.8, weight: .regular))
                                        .foregroundColor(.gray)
                                }
                                .frame(height: 50, alignment: .leading)
                                .padding(.top, 3)
                                .padding(.leading, 8)
                                Spacer()
                            }
                            .padding(.leading, 8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .background(Color.white)
        .fullScreenCover(item: $selectedVideo) { video in
            VideoPlayerScreen(
                video: video,
                character: nil as Character?,
                anime: nil as Anime?,
                allVideos: videos,
                onSave: { newTitle, newTags in
                    // 編集処理（必要ならここも拡張）
                },
                onDelete: {
                    print("[DEBUG] AlbumVideoListScreen: onDeleteコールバックが呼ばれました")
                    // 親画面に削除を通知
                    onVideoDeleted?(video)
                    // 画面を閉じる
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

// Navigation button style that highlights on press
struct VideoNavigationButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(configuration.isPressed ? .black : .gray)
    }
}

#Preview {
    VideoGalleryScreen(character: Character(id: UUID(), imageIdentifier: nil, name: "キャラクター名", tag: "タグ", birthday: Date(), favoriteFood: "", age: "", voiceActor: "", cupSize: "", seichi: "", height: ""))
} 