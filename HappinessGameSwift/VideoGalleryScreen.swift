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
    var viewCount: Int? = 0 // View count
}

struct Album: Identifiable, Hashable, Equatable, Codable {
    let id: UUID
    let tag: String
    var videos: [MemoryVideo]
    
    init(tag: String, videos: [MemoryVideo]) {
        self.id = UUID()
        self.tag = tag
        self.videos = videos
    }
    
    // Custom initializer for decoding to ensure ID is preserved
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.tag = try container.decode(String.self, forKey: .tag)
        self.videos = try container.decode([MemoryVideo].self, forKey: .videos)
    }
    
    // Custom encoder
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(tag, forKey: .tag)
        try container.encode(videos, forKey: .videos)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, tag, videos
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
    @State private var showIconAdjustment = false
    @State private var backgroundObserver: NSObjectProtocol?
    
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
            if let imageIdentifier = currentCharacter.imageIdentifier {
                OptimizedFileImage(
                    path: imageIdentifier,
                    targetSize: CGSize(width: UIScreen.main.bounds.width, height: 60)
                )
                .aspectRatio(contentMode: .fill)
                .frame(width: UIScreen.main.bounds.width - 32, height: 60)
                .scaleEffect(CGFloat(currentCharacter.iconScale))
                .offset(x: CGFloat(currentCharacter.iconOffsetX), y: CGFloat(currentCharacter.iconOffsetY))
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
                    Text(NSLocalizedString("video", comment: "Video"))
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
                    Text(NSLocalizedString("album", comment: "Album"))
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
                
                Text(NSLocalizedString("no_albums_yet", comment: "No albums yet"))
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(NSLocalizedString("create_album_from_videos", comment: "Create album from videos"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button(action: {
                    activeSheet = .tagInput
                }) {
                    Label(NSLocalizedString("create_album", comment: "Create album"), systemImage: "plus.circle.fill")
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
                VStack(spacing: 12) {
                    ForEach(albums) { album in
                        Button(action: {
                            selectedAlbum = album
                        }) {
                            ZStack {
                                // 背景画像
                                if let firstVideo = album.videos.first, let thumbnailData = firstVideo.thumbnailData {
                                    OptimizedThumbnailView(
                                        imageData: thumbnailData,
                                        size: CGSize(width: UIScreen.main.bounds.width - 40, height: 180)
                                    )
                                        .clipped()
                                } else if let firstVideo = album.videos.first, let youtubeThumbnailURL = firstVideo.youtubeThumbnailURL {
                                    AsyncImage(url: URL(string: youtubeThumbnailURL)) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(height: 180)
                                            .clipped()
                                    } placeholder: {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(height: 180)
                                            .overlay(ProgressView())
                                    }
                                } else {
                                    Rectangle()
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [Color.purple.opacity(0.7), Color.blue.opacity(0.7)]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(height: 180)
                                }
                                
                                // グラデーションオーバーレイ
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.black.opacity(0.4), Color.clear]),
                                            startPoint: .bottom,
                                            endPoint: .top
                                        )
                                    )
                                    .frame(height: 180)
                                
                                // テキスト情報
                                VStack(alignment: .leading, spacing: 4) {
                                    Spacer()
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(album.tag)
                                                .font(.system(size: 20, weight: .bold))
                                                .foregroundColor(.white)
                                            Text(String(format: NSLocalizedString("videos_individual_count", comment: "Video count"), album.videos.count))
                                                .font(.system(size: 14))
                                                .foregroundColor(.white.opacity(0.8))
                                        }
                                        Spacer()
                                        
                                        // 3点ボタン
                                        Button(action: {
                                            activeAlert = .deleteAlbum(album)
                                        }) {
                                            Image(systemName: "ellipsis")
                                                .font(.system(size: 18))
                                                .foregroundColor(.white)
                                                .rotationEffect(.degrees(90))
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 12)
                                }
                            }
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 8)
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
                    
                    Text(NSLocalizedString("no_videos_yet", comment: "No videos yet"))
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(NSLocalizedString("add_video_instruction", comment: "Add video instruction"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button(action: {
                        showAddSheet = true
                    }) {
                        Label(NSLocalizedString("add_video", comment: "Add video"), systemImage: "plus.circle.fill")
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
                                Spacer().frame(height: 15.9)
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
    
    // Increment view count for a video
    private func incrementViewCount(for video: MemoryVideo) {
        if let index = videos.firstIndex(where: { $0.id == video.id }) {
            var updatedVideo = videos[index]
            updatedVideo.viewCount = (updatedVideo.viewCount ?? 0) + 1
            videos[index] = updatedVideo
            saveVideosToUserDefaults()
        }
    }
    
    // View count formatter
    private func formatViewCount(_ count: Int) -> String {
        if count >= 10000 {
            let formatted = Double(count) / 10000.0
            return String(format: NSLocalizedString("ten_thousand", comment: "10k format"), formatted)
        } else {
            return "\(count)"
        }
    }
    
    // Time ago formatter
    private func timeAgo(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date, to: now)
        
        if let years = components.year, years > 0 {
            return String(format: NSLocalizedString("years_ago", comment: "Years ago"), years)
        } else if let months = components.month, months > 0 {
            return String(format: NSLocalizedString("months_ago", comment: "Months ago"), months)
        } else if let days = components.day, days > 0 {
            return String(format: NSLocalizedString("days_ago", comment: "Days ago"), days)
        } else if let hours = components.hour, hours > 0 {
            return String(format: NSLocalizedString("hours_ago", comment: "Hours ago"), hours)
        } else if let minutes = components.minute, minutes > 0 {
            return String(format: NSLocalizedString("minutes_ago", comment: "Minutes ago"), minutes)
        } else {
            return NSLocalizedString("just_now", comment: "Just now")
        }
    }
    
    // ビデオ行ビュー
    func videoRowView(video: MemoryVideo) -> some View {
        Button(action: {
            // YouTube動画の場合は確認ページを表示
            if let youtubeURL = video.youtubeURL, !youtubeURL.isEmpty {
                activeSheet = .youtubeConfirmation(video)
                // YouTubeの場合、開いた時点でカウント
                incrementViewCount(for: video)
            } else {
                selectedVideo = video
                // 通常動画の場合もカウント
                incrementViewCount(for: video)
            }
        }) {
            HStack(alignment: .top, spacing: 8) {
                // サムネイル
                if let thumbnailData = video.thumbnailData {
                    OptimizedThumbnailView(
                        imageData: thumbnailData,
                        size: CGSize(width: 165, height: 90)
                    )
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .clipped()
                } else if let youtubeThumbnailURL = video.youtubeThumbnailURL {
                    AsyncImage(url: URL(string: youtubeThumbnailURL)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 165, height: 90)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .clipped()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 165, height: 90)
                            .overlay(ProgressView())
                    }
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 165, height: 90)
                }
                
                // タイトルとタグ
                VStack(alignment: .leading, spacing: 2) {
                    Text(video.title.formatVideoTitle())
                        .font(.system(size: 16.5, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.vertical, 4)
                        .multilineTextAlignment(.leading)
                    
                    // ハッシュタグ
                    if let firstTag = video.tags.first {
                        Text("#\(firstTag)")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.gray)
                    }
                    
                    Text("\(formatViewCount(video.viewCount ?? 0))回・\(timeAgo(from: video.date))")
                        .font(.system(size: 13.8, weight: .regular))
                        .foregroundColor(.gray)
                        .padding(.vertical, 1)
                }
                .frame(alignment: .leading)
                .padding(.top, 3)
                .padding(.leading, 8)
                
                Spacer()
                
                // メニューボタン
                Menu {
                    Button(action: {
                        editText = video.title
                        activeSheet = .editTitle(video)
                    }) {
                        Label(NSLocalizedString("edit_title", comment: "Edit title"), systemImage: "pencil")
                    }
                    Button(action: {
                        editText = video.tags.joined(separator: ", ")
                        activeSheet = .editTags(video)
                    }) {
                        Label(NSLocalizedString("edit_tags", comment: "Edit tags"), systemImage: "tag")
                    }
                    Button(action: {
                        activeSheet = .thumbnailPicker(video)
                    }) {
                        Label(NSLocalizedString("change_thumbnail", comment: "Change thumbnail"), systemImage: "photo")
                    }
                    Divider()
                    Button(role: .destructive, action: {
                        activeAlert = .deleteVideo(video.id)
                    }) {
                        Label(NSLocalizedString("delete", comment: "Delete"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18))
                        .foregroundColor(.gray)
                        .rotationEffect(.degrees(90))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .frame(width: 60, height: 60)
                .contentShape(Rectangle())
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
                Text(String(format: NSLocalizedString("video_album_count", comment: "Video album count"), videos.count, albums.count))
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
                        Text(NSLocalizedString("back", comment: "Back"))
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
                        Text(NSLocalizedString("video", comment: "Video"))
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
                        Text(NSLocalizedString("album", comment: "Album"))
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
                        Text(NSLocalizedString("about", comment: "About"))
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
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showIconAdjustment = true
                        }
                    
                    // Profile section
                    profileSection
                    
                    // Description section
                    descriptionSection
                    
                    // Add button moved here
                    Button(action: { 
                        if showAlbum {
                            activeSheet = .tagInput
                        } else {
                            videoTitle = ""
                            videoTags = ""
                            showAddSheet = true 
                        }
                    }) {
                        Text(showAlbum ? NSLocalizedString("video_add_album", comment: "Add album") : NSLocalizedString("video_add_video", comment: "Add video"))
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
        // サントラプレイヤーを表示
        .overlay(
            VStack {
                Spacer()
                SoundtrackPlayerView()
                    .padding(.bottom, 70)
            }
        )
        .onAppear {
            print("📱 [VideoGallery] onAppear called for character: \(character.name)")
            print("📱 [VideoGallery] Character ID: \(character.id.uuidString)")
            loadVideos()
            loadAlbumsFromUserDefaults()
            setupBackgroundObserver()
            
            // Debug: Print all album keys
            VideoStorage.shared.debugPrintAllAlbumKeys()
            
            // Debug: Check for specific key
            let expectedKey = "video_albums_\(character.id.uuidString)"
            if let data = UserDefaults.standard.data(forKey: expectedKey) {
                print("📱 [VideoGallery] Key '\(expectedKey)' exists with \(data.count) bytes")
            } else {
                print("📱 [VideoGallery] Key '\(expectedKey)' does NOT exist")
            }
            
            // Debug: Try to load directly if albums are empty
            if albums.isEmpty {
                print("📱 [VideoGallery] Albums are empty after load, checking for data issues...")
                
                // Try to load and decode directly
                if let data = UserDefaults.standard.data(forKey: expectedKey) {
                    do {
                        let decoded = try JSONDecoder().decode([Album].self, from: data)
                        print("📱 [VideoGallery] Direct decode successful: \(decoded.count) albums")
                        print("⚠️ [VideoGallery] loadAlbumsFromUserDefaults may have failed, using direct decode")
                        albums = decoded
                    } catch {
                        print("📱 [VideoGallery] Direct decode failed: \(error)")
                    }
                }
            }
        }
        .onDisappear {
            print("📱 [VideoGallery] onDisappear - saving albums before view dismisses")
            saveAlbumsToUserDefaults()
            removeBackgroundObserver()
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
                return Alert(
                    title: Text(NSLocalizedString("delete_video_confirm_title", comment: "Delete video?")),
                    message: Text(NSLocalizedString("delete_video_confirm_message", comment: "Delete permanently")),
                    primaryButton: .destructive(Text(NSLocalizedString("delete", comment: "Delete"))) {
                        deleteVideo(id: videoId)
                    },
                    secondaryButton: .cancel(Text(NSLocalizedString("cancel", comment: "Cancel"))) {
                    }
                )
            case .deleteAlbum(let album):
                return Alert(
                    title: Text(NSLocalizedString("delete_album_confirm_title", comment: "Delete album?")),
                    message: Text(NSLocalizedString("delete_album_confirm_message", comment: "Delete permanently")),
                    primaryButton: .destructive(Text(NSLocalizedString("delete", comment: "Delete"))) {
                        deleteAlbum(album)
                    },
                    secondaryButton: .cancel(Text(NSLocalizedString("cancel", comment: "Cancel")))
                )
            case .youtubeError(let message):
                return Alert(
                    title: Text(NSLocalizedString("youtube_download_error", comment: "YouTube error")),
                    message: Text(message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .sheet(isPresented: $showIconAdjustment) {
            CharacterIconAdjustmentView(
                character: Binding(
                    get: { currentCharacter },
                    set: { updatedCharacter in
                        if let index = characterManager.characters.firstIndex(where: { $0.id == character.id }) {
                            characterManager.characters[index] = updatedCharacter
                            characterManager.updateCharacter(updatedCharacter)
                        }
                    }
                ),
                characterManager: characterManager
            )
        }
    }
    
    // メインコンテンツ
    
    // フローティングボタン
    var floatingButton: some View {
        EmptyView()
    }
    
    // タグ入力シート
    var tagInputSheet: some View {
        VStack(spacing: 24) {
            Text(NSLocalizedString("create_album_instruction", comment: "Create album instruction"))
                .font(.headline)
            TextField(NSLocalizedString("tag_name_placeholder", comment: "Tag name"), text: $newTag)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal, 24)
            Button(NSLocalizedString("save", comment: "Save")) {
                let tag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
                if !tag.isEmpty {
                    let tagVideos = videos.filter { $0.tags.contains(where: { $0 == tag }) }
                    if !tagVideos.isEmpty {
                        let newAlbum = Album(tag: tag, videos: tagVideos)
                        print("📱 [VideoGallery] Creating new album '\(tag)' with \(tagVideos.count) videos")
                        print("📱 [VideoGallery] New album ID: \(newAlbum.id)")
                        albums.append(newAlbum)
                        print("📱 [VideoGallery] Total albums after adding: \(albums.count)")
                        saveAlbumsToUserDefaults()
                    } else {
                        print("📱 [VideoGallery] No videos found with tag '\(tag)'")
                    }
                } else {
                    print("📱 [VideoGallery] Tag is empty, not creating album")
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
            Button(NSLocalizedString("cancel", comment: "Cancel")) {
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
            Text(NSLocalizedString("edit_title", comment: "Edit title"))
                .font(.headline)
                .padding(.top, 24)
            
            TextField(NSLocalizedString("title", comment: "Title"), text: $editText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.system(size: 18))
                .padding(.horizontal, 24)
            
            HStack(spacing: 24) {
                Button(action: {
                    activeSheet = nil
                }) {
                    Text(NSLocalizedString("cancel", comment: "Cancel"))
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
                    Text(NSLocalizedString("save", comment: "Save"))
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
            Text(NSLocalizedString("edit_tags", comment: "Edit tags"))
                .font(.headline)
                .padding(.top, 24)
            
            TextField(NSLocalizedString("tags_comma_separated", comment: "Tags (comma separated)"), text: $editText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.system(size: 18))
                .padding(.horizontal, 24)
            
            HStack(spacing: 24) {
                Button(action: {
                    activeSheet = nil
                }) {
                    Text(NSLocalizedString("cancel", comment: "Cancel"))
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
                    Text(NSLocalizedString("save", comment: "Save"))
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
                        Text(NSLocalizedString("downloading_youtube_video", comment: "Downloading YouTube video"))
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
                
                Text(video.title.formatVideoTitle())
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
                        Text(NSLocalizedString("open_in_youtube", comment: "Open in YouTube"))
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
                    Text(NSLocalizedString("close", comment: "Close"))
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
                Text(String(format: NSLocalizedString("title_label", comment: ""), video.title))
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
                Text(String(format: NSLocalizedString("tags_label", comment: ""), video.tags.joined(separator: ", ")))
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
                        Text(NSLocalizedString("close", comment: "Close"))
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
                TextField(NSLocalizedString("title", comment: "Title"), text: $editText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 18))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                HStack(spacing: 24) {
                    Button(action: { showEditTitle = false }) {
                        Text(NSLocalizedString("cancel", comment: "Cancel"))
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
                        Text(NSLocalizedString("save", comment: "Save"))
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
                Text(NSLocalizedString("edit_tags", comment: "Edit tags"))
                    .font(.headline)
                    .padding(.top, 12)
                TextField(NSLocalizedString("tags_comma_separated", comment: "Tags (comma separated)"), text: $editText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 18))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                HStack(spacing: 24) {
                    Button(action: { showEditTags = false }) {
                        Text(NSLocalizedString("cancel", comment: "Cancel"))
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
                        Text(NSLocalizedString("save", comment: "Save"))
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
            }
        }
        
        let newVideo = MemoryVideo(id: UUID(), characterId: character.id, videoPath: documentsPath, thumbnailData: thumbnailData, title: videoTitle, tags: tags, date: Date(), youtubeURL: nil, youtubeThumbnailURL: nil)
        videos.insert(newVideo, at: 0)
        saveVideosToUserDefaults()
        
        // Check for existing albums with matching tags and add the video
        addVideoToMatchingAlbums(newVideo)
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
            
            var fileURL = appDirectoryURL.appendingPathComponent(fileName)
            
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
            try fileManager.copyItem(at: url, to: fileURL)
            
            // iCloudバックアップを有効にする
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = false
            try fileURL.setResourceValues(resourceValues)
            
            return "AnirecoImages/\(fileName)"
        } catch {
            return ""
        }
    }
    
    private func loadVideos() {
        videos = VideoStorage.shared.loadVideos(for: character.id.uuidString)
    }
    
    private func saveVideosToUserDefaults() {
        VideoStorage.shared.saveVideos(for: character.id.uuidString, videos: videos)
    }
    
    private func saveAlbumsToUserDefaults() {
        print("📱 [VideoGallery] Saving \(albums.count) albums for character: \(character.name) (ID: \(character.id.uuidString))")
        
        // Log album details before saving
        for album in albums {
            print("📱 [VideoGallery]   - Album '\(album.tag)' with \(album.videos.count) videos")
        }
        
        VideoStorage.shared.saveAlbums(for: character.id.uuidString, albums: albums)
    }
    
    private func loadAlbumsFromUserDefaults() {
        print("📱 [VideoGallery] Loading albums for character: \(character.name) (ID: \(character.id.uuidString))")
        
        // Debug print all album keys before loading
        VideoStorage.shared.debugPrintAllAlbumKeys()
        
        // Removed test album persistence to prevent interfering with actual data
        
        albums = VideoStorage.shared.loadAlbums(for: character.id.uuidString)
        print("📱 [VideoGallery] Loaded \(albums.count) albums")
        
        // Debug print loaded albums
        for album in albums {
            print("📱 [VideoGallery]   - Album '\(album.tag)' with \(album.videos.count) videos")
        }
    }
    
    private func deleteVideo(id: UUID) {
        if let idx = videos.firstIndex(where: { $0.id == id }) {
            videos.remove(at: idx)
            updateAlbumsAfterVideoDeletion(deletedVideoId: id)
            saveVideosToUserDefaults()
            saveAlbumsToUserDefaults()
            
            // 動画が削除されたことを通知
            NotificationCenter.default.post(name: Notification.Name("VideoDeleted"), object: nil)
        } else {
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
    }
    
    private func deleteAlbum(_ album: Album) {
        if let index = albums.firstIndex(where: { $0.id == album.id }) {
            albums.remove(at: index)
            saveAlbumsToUserDefaults()
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
        
        // Check for existing albums with matching tags and add the video
        addVideoToMatchingAlbums(newVideo)
        
        selectedThumbnailData = nil // リセット
        showAddSheet = false
    }
    
    // Add video to albums with matching tags
    private func addVideoToMatchingAlbums(_ video: MemoryVideo) {
        var albumsUpdated = false
        
        for (index, album) in albums.enumerated() {
            // Check if the video has the same tag as the album
            if video.tags.contains(album.tag) {
                // Check if the video is not already in the album
                if !albums[index].videos.contains(where: { $0.id == video.id }) {
                    albums[index].videos.append(video)
                    albumsUpdated = true
                }
            }
        }
        
        // Save albums if any were updated
        if albumsUpdated {
            saveAlbumsToUserDefaults()
        }
    }
    
    private func setupBackgroundObserver() {
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            print("📱 [VideoGallery] App entering background - saving albums")
            saveAlbumsToUserDefaults()
        }
    }
    
    private func removeBackgroundObserver() {
        if let observer = backgroundObserver {
            NotificationCenter.default.removeObserver(observer)
            backgroundObserver = nil
        }
    }
    
    private func downloadYouTubeVideo(youtubeURL: String) async throws -> URL {
        // Use server-side proxy endpoint for YouTube downloads
        let endpoint = Bundle.main.infoDictionary?["YOUTUBE_DOWNLOAD_API_ENDPOINT"] as? String ?? "https://happiness-game.onrender.com/api/youtube-download"
        
        guard let apiURL = URL(string: endpoint) else {
            throw NSError(domain: "URL生成エラー", code: 0)
        }
        // Create POST request to server proxy
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Send YouTube URL to server
        let body = ["youtubeUrl": youtubeURL]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "APIリクエスト失敗", code: 0)
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
                            Text(video.title.formatVideoTitle())
                                .font(.system(size: 16.5, weight: .semibold))
                                .foregroundColor(.black)
                                .multilineTextAlignment(.leading)
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
    @State private var activeAlert: ActiveAlert? = nil
    @State private var activeSheet: ActiveSheet? = nil
    @State private var editText = ""
    @State private var localVideos: [MemoryVideo] = []
    
    enum ActiveAlert: Identifiable {
        case deleteVideo(UUID)
        case youtubeError(String)
        
        var id: String {
            switch self {
            case .deleteVideo: return "deleteVideo"
            case .youtubeError: return "youtubeError"
            }
        }
    }
    
    enum ActiveSheet: Identifiable {
        case editTitle(MemoryVideo)
        case editTags(MemoryVideo)
        case thumbnailPicker(MemoryVideo)
        case youtubeConfirmation(MemoryVideo)
        
        var id: String {
            switch self {
            case .editTitle: return "editTitle"
            case .editTags: return "editTags"
            case .thumbnailPicker: return "thumbnailPicker"
            case .youtubeConfirmation: return "youtubeConfirmation"
            }
        }
    }
    
    // Increment view count for a video
    private func incrementViewCount(for video: MemoryVideo) {
        if let index = localVideos.firstIndex(where: { $0.id == video.id }) {
            var updatedVideo = localVideos[index]
            updatedVideo.viewCount = (updatedVideo.viewCount ?? 0) + 1
            localVideos[index] = updatedVideo
            saveViewCount()
        }
    }
    
    private func saveViewCount() {
        // Save to UserDefaults through parent
        // This is a simplified approach - in production, you'd properly sync with parent
    }
    
    // View count formatter
    private func formatViewCount(_ count: Int) -> String {
        if count >= 10000 {
            let formatted = Double(count) / 10000.0
            return String(format: NSLocalizedString("ten_thousand", comment: "10k format"), formatted)
        } else {
            return "\(count)"
        }
    }
    
    // Time ago formatter
    private func timeAgo(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date, to: now)
        
        if let years = components.year, years > 0 {
            return String(format: NSLocalizedString("years_ago", comment: "Years ago"), years)
        } else if let months = components.month, months > 0 {
            return String(format: NSLocalizedString("months_ago", comment: "Months ago"), months)
        } else if let days = components.day, days > 0 {
            return String(format: NSLocalizedString("days_ago", comment: "Days ago"), days)
        } else if let hours = components.hour, hours > 0 {
            return String(format: NSLocalizedString("hours_ago", comment: "Hours ago"), hours)
        } else if let minutes = components.minute, minutes > 0 {
            return String(format: NSLocalizedString("minutes_ago", comment: "Minutes ago"), minutes)
        } else {
            return NSLocalizedString("just_now", comment: "Just now")
        }
    }
    
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
                                .onAppear {
                                }
                        } else if let youtubeThumbnailURL = firstVideo.youtubeThumbnailURL {
                            AsyncImage(url: URL(string: youtubeThumbnailURL)) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .onAppear {
                                    }
                            } placeholder: {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .overlay(ProgressView())
                                    .onAppear {
                                    }
                            }
                            .onAppear {
                            }
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .onAppear {
                                }
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
                        Text(String(format: NSLocalizedString("videos_count_format", comment: "Video count"), videos.count))
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
                    ForEach(Array(videos.enumerated()), id: \.element.id) { idx, video in
                        if idx > 0 {
                            Spacer().frame(height: 15.9)
                        }
                        Button(action: {
                            // YouTube動画の場合は確認ページを表示
                            if let youtubeURL = video.youtubeURL, !youtubeURL.isEmpty {
                                activeSheet = .youtubeConfirmation(video)
                                // YouTubeの場合、開いた時点でカウント
                                incrementViewCount(for: video)
                            } else {
                                selectedVideo = video
                                // 通常動画の場合もカウント
                                incrementViewCount(for: video)
                            }
                        }) {
                            HStack(alignment: .top, spacing: 8) {
                                // サムネイル
                                if let thumbnailData = video.thumbnailData, let uiImage = UIImage(data: thumbnailData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 165, height: 90)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                        .clipped()
                                } else if let youtubeThumbnailURL = video.youtubeThumbnailURL {
                                    AsyncImage(url: URL(string: youtubeThumbnailURL)) { image in
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 165, height: 90)
                                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                            .clipped()
                                    } placeholder: {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 165, height: 90)
                                            .overlay(ProgressView())
                                    }
                                } else {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 165, height: 90)
                                }
                                
                                // タイトルとタグ
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(video.title.formatVideoTitle())
                                        .font(.system(size: 16.5, weight: .semibold))
                                        .foregroundColor(.black)
                                        .padding(.vertical, 4)
                                        .multilineTextAlignment(.leading)
                                    
                                    // ハッシュタグ
                                    if let firstTag = video.tags.first {
                                        Text("#\(firstTag)")
                                            .font(.system(size: 12, weight: .regular))
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Text("\(formatViewCount(video.viewCount ?? 0))回・\(timeAgo(from: video.date))")
                                        .font(.system(size: 13.8, weight: .regular))
                                        .foregroundColor(.gray)
                                        .padding(.vertical, 1)
                                }
                                .frame(alignment: .leading)
                                .padding(.top, 3)
                                .padding(.leading, 8)
                                
                                Spacer()
                                
                                // メニューボタン
                                Menu {
                                    Button(action: {
                                        editText = video.title
                                        activeSheet = .editTitle(video)
                                    }) {
                                        Label(NSLocalizedString("edit_title", comment: "Edit title"), systemImage: "pencil")
                                    }
                                    Button(action: {
                                        editText = video.tags.joined(separator: ", ")
                                        activeSheet = .editTags(video)
                                    }) {
                                        Label(NSLocalizedString("edit_tags", comment: "Edit tags"), systemImage: "tag")
                                    }
                                    Button(action: {
                                        activeSheet = .thumbnailPicker(video)
                                    }) {
                                        Label(NSLocalizedString("change_thumbnail", comment: "Change thumbnail"), systemImage: "photo")
                                    }
                                    Divider()
                                    Button(role: .destructive, action: {
                                        activeAlert = .deleteVideo(video.id)
                                    }) {
                                        Label(NSLocalizedString("delete", comment: "Delete"), systemImage: "trash")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis")
                                        .font(.system(size: 18))
                                        .foregroundColor(.gray)
                                        .rotationEffect(.degrees(90))
                                }
                                .frame(height: 50)
                                .padding(.trailing, 16)
                            }
                            .padding(.leading, 8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .background(Color.white)
        .onAppear {
            localVideos = videos
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
                        if let idx = localVideos.firstIndex(where: { $0.id == video.id }) {
                            var updated = localVideos[idx]
                            updated.thumbnailData = newThumbnailData
                            localVideos[idx] = updated
                        }
                        activeSheet = nil
                    },
                    onCancel: {
                        activeSheet = nil
                    }
                )
            case .youtubeConfirmation(let video):
                youtubeConfirmationSheet(video: video)
            }
        }
        .alert(item: $activeAlert) { alertType in
            switch alertType {
            case .deleteVideo(let videoId):
                return Alert(
                    title: Text(NSLocalizedString("delete_video_confirm_title", comment: "Delete video?")),
                    message: Text(NSLocalizedString("delete_video_confirm_message", comment: "Delete permanently")),
                    primaryButton: .destructive(Text(NSLocalizedString("delete", comment: "Delete"))) {
                        if let video = localVideos.first(where: { $0.id == videoId }) {
                            onVideoDeleted?(video)
                            if let idx = localVideos.firstIndex(where: { $0.id == videoId }) {
                                localVideos.remove(at: idx)
                            }
                        }
                    },
                    secondaryButton: .cancel(Text(NSLocalizedString("cancel", comment: "Cancel")))
                )
            case .youtubeError(let message):
                return Alert(
                    title: Text("エラー"),
                    message: Text(message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
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
                    // 親画面に削除を通知
                    onVideoDeleted?(video)
                    // 画面を閉じる
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
    
    // タイトル編集シート
    func editTitleSheet(video: MemoryVideo) -> some View {
        VStack(spacing: 24) {
            Text(NSLocalizedString("edit_title", comment: "Edit title"))
                .font(.headline)
                .padding(.top, 24)
            
            TextField(NSLocalizedString("title", comment: "Title"), text: $editText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.system(size: 18))
                .padding(.horizontal, 24)
            
            HStack(spacing: 24) {
                Button(action: {
                    activeSheet = nil
                }) {
                    Text(NSLocalizedString("cancel", comment: "Cancel"))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
                
                Button(action: {
                    if let idx = localVideos.firstIndex(where: { $0.id == video.id }) {
                        var updated = localVideos[idx]
                        updated.title = editText
                        localVideos[idx] = updated
                    }
                    activeSheet = nil
                }) {
                    Text(NSLocalizedString("save", comment: "Save"))
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
            Text(NSLocalizedString("edit_tags", comment: "Edit tags"))
                .font(.headline)
                .padding(.top, 24)
            
            TextField(NSLocalizedString("tags_comma_separated", comment: "Tags (comma separated)"), text: $editText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.system(size: 18))
                .padding(.horizontal, 24)
            
            HStack(spacing: 24) {
                Button(action: {
                    activeSheet = nil
                }) {
                    Text(NSLocalizedString("cancel", comment: "Cancel"))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
                
                Button(action: {
                    if let idx = localVideos.firstIndex(where: { $0.id == video.id }) {
                        var updated = localVideos[idx]
                        updated.tags = editText.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                        localVideos[idx] = updated
                    }
                    activeSheet = nil
                }) {
                    Text(NSLocalizedString("save", comment: "Save"))
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
                
                Text(video.title.formatVideoTitle())
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
                        Text(NSLocalizedString("open_in_youtube", comment: "Open in YouTube"))
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
                    Text(NSLocalizedString("close", comment: "Close"))
                        .foregroundColor(.gray)
                        .padding()
                }
            }
            
            Spacer()
        }
        .background(Color(.systemBackground))
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
    VideoGalleryScreen(character: Character(
        id: UUID(),
        imageIdentifier: nil,
        name: "キャラクター名",
        tag: "タグ",
        birthday: Date(),
        favoriteFood: "",
        age: "",
        voiceActor: "",
        cupSize: "",
        seichi: "",
        height: ""
    ))
}

// String extension for video title formatting
extension String {
    func chunked(_ length: Int) -> [String] {
        var result: [String] = []
        var start = startIndex
        while start < endIndex {
            let end = index(start, offsetBy: length, limitedBy: endIndex) ?? endIndex
            result.append(String(self[start..<end]))
            start = end
        }
        return result
    }
    
    // Format video titles: 8 characters per line, truncate after 15 characters with ellipsis
    func formatVideoTitle() -> String {
        // Count actual characters (not bytes) for proper Japanese text handling
        let characters = Array(self)
        
        if characters.count <= 8 {
            // If 8 characters or less, return as is
            return self
        } else if characters.count <= 15 {
            // If 9-15 characters, split into two lines at 8 characters
            let firstLine = String(characters.prefix(8))
            let secondLine = String(characters.dropFirst(8))
            return "\(firstLine)\n\(secondLine)"
        } else {
            // If more than 15 characters, truncate to 15 and add ellipsis
            let truncated = String(characters.prefix(15)) + "..."
            let truncatedChars = Array(truncated)
            let firstLine = String(truncatedChars.prefix(8))
            let secondLine = String(truncatedChars.dropFirst(8))
            return "\(firstLine)\n\(secondLine)"
        }
    }
}

 