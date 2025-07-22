    private var contentView: some View {
        if showAlbum {
            // Album content
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
                        showTagInput = true
                    }) {
                        Label("アルバムを作成", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
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
                                            .frame(width: 80, height: 80)
                                            .clipped()
                                            .cornerRadius(8)
                                    } else {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 80, height: 80)
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
                                    
                                    // 右端の#ボタン
                                    Button(action: {
                                        // #ボタンのアクション
                                    }) {
                                        Text("#")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(width: 32, height: 32)
                                            .background(Color.black)
                                            .clipShape(Circle())
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.white)
                                .cornerRadius(8)
                                .shadow(radius: 1)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
        } else {
            // Video content
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
                            .padding()
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
                            Button(action: {
                                selectedVideo = video
                            }) {
                                HStack(alignment: .top, spacing: 16) {
                                    if let thumbnailData = video.thumbnailData, let uiImage = UIImage(data: thumbnailData) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 183, height: 109)
                                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                            .clipped()
                                    } else if let youtubeThumbnailURL = video.youtubeThumbnailURL {
                                        AsyncImage(url: URL(string: youtubeThumbnailURL)) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: 183, height: 109)
                                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                                .clipped()
                                        } placeholder: {
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .fill(Color.gray.opacity(0.3))
                                                .frame(width: 183, height: 109)
                                                .overlay(
                                                    ProgressView()
                                                )
                                        }
                                    } else {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 183, height: 109)
                                    }
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
                                    Menu {
                                        Button(action: {
                                            // タイトル編集
                                        }) {
                                            Label("タイトルを編集", systemImage: "pencil")
                                        }
                                        Button(action: {
                                            // タグ編集
                                        }) {
                                            Label("タグを編集", systemImage: "tag")
                                        }
                                        Button(action: {
                                            // サムネイル変更
                                        }) {
                                            Label("サムネイルを変更", systemImage: "photo")
                                        }
                                        Divider()
                                        Button(role: .destructive, action: {
                                            deletingVideoID = video.id
                                            showDeleteVideoAlert = true
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
                    }
                }
            }
        }
    }