import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'memory_screen.dart'; // Characterクラスを利用
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'dart:html' as html;

class _VideoItem {
  final String? filePath;
  final String? webUrl;
  final String title;
  final String hashtag;
  _VideoItem({this.filePath, this.webUrl, required this.title, required this.hashtag});
}

class VideoGalleryScreen extends StatefulWidget {
  final Character character;
  const VideoGalleryScreen({Key? key, required this.character}) : super(key: key);

  @override
  State<VideoGalleryScreen> createState() => _VideoGalleryScreenState();
}

class _VideoGalleryScreenState extends State<VideoGalleryScreen> {
  List<_VideoItem> videos = [];

  void _addVideo() async {
    await showDialog(
      context: context,
      builder: (context) {
        final titleController = TextEditingController();
        final hashtagController = TextEditingController();
        String? errorText;
        String? localFilePath;
        String? localWebUrl;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: Colors.white,
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('動画アップロード', style: TextStyle(fontSize: 18, color: Colors.black, fontWeight: FontWeight.bold)),
                    SizedBox(height: 24),
                    GestureDetector(
                      onTap: () async {
                        if (kIsWeb) {
                          final result = await FilePicker.platform.pickFiles(type: FileType.video);
                          if (result == null || result.files.isEmpty) return;
                          final bytes = result.files.first.bytes;
                          final name = result.files.first.name;
                          if (bytes == null) return;
                          final blob = html.Blob([bytes]);
                          setStateDialog(() {
                            localWebUrl = html.Url.createObjectUrlFromBlob(blob);
                            localFilePath = null;
                          });
                        } else {
                          final picker = ImagePicker();
                          final pickedFile = await picker.pickVideo(source: ImageSource.gallery);
                          if (pickedFile == null) return;
                          final appDir = await getApplicationDocumentsDirectory();
                          final fileName = DateTime.now().millisecondsSinceEpoch.toString() + '_' + (pickedFile.name);
                          final savePath = '${appDir.path}/$fileName';
                          await File(pickedFile.path).copy(savePath);
                          setStateDialog(() {
                            localFilePath = savePath;
                            localWebUrl = null;
                          });
                        }
                      },
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!, width: 1),
                        ),
                        child: (kIsWeb
                          ? (localWebUrl == null
                            ? Icon(Icons.video_library, color: Colors.grey[600], size: 32)
                            : VideoPlayerPreviewWeb(url: localWebUrl!))
                          : (localFilePath == null
                            ? Icon(Icons.video_library, color: Colors.grey[600], size: 32)
                            : VideoPlayerPreview(file: File(localFilePath!)))),
                      ),
                    ),
                    SizedBox(height: 24),
                    TextField(
                      controller: titleController,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.black),
                      decoration: InputDecoration(
                        hintText: 'タイトル',
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.black),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextField(
                      controller: hashtagController,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.black),
                      decoration: InputDecoration(
                        hintText: 'タグ（例: #アニメ #声優）',
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.black),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    SizedBox(height: 24),
                    if (errorText != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          errorText!,
                          style: TextStyle(color: Colors.red[700], fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(foregroundColor: Colors.black),
                            child: Text('キャンセル'),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final title = titleController.text.trim();
                              final hashtag = hashtagController.text.trim();
                              String? error;
                              if (title.isEmpty) {
                                error = 'タイトルを入力してください';
                              } else if (hashtag.isEmpty) {
                                error = 'タグを入力してください';
                              } else if ((kIsWeb && (localWebUrl == null || (localWebUrl?.isEmpty ?? true))) || (!kIsWeb && (localFilePath == null || (localFilePath?.isEmpty ?? true)))) {
                                error = '動画を選択してください';
                              }
                              if (error != null) {
                                setStateDialog(() {
                                  errorText = error;
                                });
                                return;
                              }
                              setState(() {
                                videos.insert(0, _VideoItem(filePath: localFilePath, webUrl: localWebUrl, title: title, hashtag: hashtag));
                              });
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                            ),
                            child: Text('保存'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: Padding(
            padding: const EdgeInsets.only(left: 15.0, top: 50.0),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          centerTitle: true,
          title: Padding(
            padding: const EdgeInsets.only(top: 50.0),
            child: Text(
              widget.character.name,
              style: TextStyle(
                color: Colors.grey[800],
                fontWeight: FontWeight.w900,
                fontSize: 20,
                fontFamily: 'NotoSansJP',
              ),
            ),
          ),
          actions: [],
          automaticallyImplyLeading: false,
          toolbarHeight: 80,
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
            child: Column(
              children: [
                const SizedBox(height: 25),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () {},
                      child: _TabText('Video', true),
                    ),
                    const SizedBox(width: 32),
                    SizedBox(width: 230),
                    GestureDetector(
                      onTap: _addVideo,
                      child: Icon(Icons.cloud_upload, size: 28, color: Colors.blue),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: videos.length,
              itemBuilder: (context, i) {
                final video = videos[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 32, left: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(22.64),
                            child: SizedBox(
                              width: 369,
                              height: 222,
                              child: kIsWeb
                                ? (video.webUrl != null
                                    ? VideoPlayerCardWeb(url: video.webUrl!)
                                    : Container(color: Colors.grey[200], width: 369, height: 222))
                                : (video.filePath != null
                                    ? VideoPlayerCard(file: File(video.filePath!))
                                    : Container(color: Colors.grey[200], width: 369, height: 222)),
                            ),
                          ),
                        ],
                      ),
                      // Row全体を横並び＋spaceBetweenで分割
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 左側：アイコン＋名前＋テキスト
                          Padding(
                            padding: const EdgeInsets.only(left: 0, top: 9),
                            child: CircleAvatar(
                              backgroundImage: widget.character.image,
                              radius: 22,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    video.title,
                                    style: const TextStyle(
                                      fontFamily: 'NotoSansJP',
                                      fontWeight: FontWeight.w500,
                                      fontSize: 15,
                                      color: Colors.black,
                                    ),
                                  ),
                                  if (video.hashtag.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2.0),
                                      child: Text(
                                        video.hashtag,
                                        style: const TextStyle(
                                          fontFamily: 'NotoSansJP',
                                          fontWeight: FontWeight.w400,
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          // 右側：３点メニュー
                          Padding(
                            padding: const EdgeInsets.only(right: 8, top: 6),
                            child: PopupMenuButton<String>(
                              icon: Icon(Icons.more_vert, color: Colors.black, size: 20),
                              onSelected: (value) {
                                if (value == 'delete') {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text('この動画を消去しますか？'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: Text('キャンセル'),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            setState(() {
                                              videos.removeAt(i);
                                            });
                                            Navigator.pop(context);
                                          },
                                          child: Text('消去', style: TextStyle(color: Colors.red)),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('消去'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class VideoPlayerPreview extends StatefulWidget {
  final File file;
  const VideoPlayerPreview({required this.file});
  @override
  State<VideoPlayerPreview> createState() => _VideoPlayerPreviewState();
}
class _VideoPlayerPreviewState extends State<VideoPlayerPreview> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.file)
      ..initialize().then((_) {
        setState(() {
          _initialized = true;
        });
      });
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return _initialized
        ? VideoPlayer(_controller)
        : Center(child: CircularProgressIndicator());
  }
}

class VideoPlayerCard extends StatefulWidget {
  final File file;
  const VideoPlayerCard({required this.file});
  @override
  State<VideoPlayerCard> createState() => _VideoPlayerCardState();
}
class _VideoPlayerCardState extends State<VideoPlayerCard> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.file)
      ..initialize().then((_) {
        setState(() {
          _initialized = true;
        });
      });
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return _initialized
        ? GestureDetector(
            onTap: () {
              setState(() {
                if (_controller.value.isPlaying) {
                  _controller.pause();
                } else {
                  _controller.play();
                }
              });
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                VideoPlayer(_controller),
                if (!_controller.value.isPlaying)
                  Icon(Icons.play_circle_outline, size: 64, color: Colors.white.withOpacity(0.7)),
              ],
            ),
          )
        : Center(child: CircularProgressIndicator());
  }
}

class VideoPlayerPreviewWeb extends StatefulWidget {
  final String url;
  const VideoPlayerPreviewWeb({required this.url});
  @override
  State<VideoPlayerPreviewWeb> createState() => _VideoPlayerPreviewWebState();
}
class _VideoPlayerPreviewWebState extends State<VideoPlayerPreviewWeb> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.url)
      ..initialize().then((_) {
        setState(() {
          _initialized = true;
        });
      });
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return _initialized
        ? VideoPlayer(_controller)
        : Center(child: CircularProgressIndicator());
  }
}

class VideoPlayerCardWeb extends StatefulWidget {
  final String url;
  const VideoPlayerCardWeb({required this.url});
  @override
  State<VideoPlayerCardWeb> createState() => _VideoPlayerCardWebState();
}
class _VideoPlayerCardWebState extends State<VideoPlayerCardWeb> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.url)
      ..initialize().then((_) {
        setState(() {
          _initialized = true;
        });
      });
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return _initialized
        ? GestureDetector(
            onTap: () {
              setState(() {
                if (_controller.value.isPlaying) {
                  _controller.pause();
                } else {
                  _controller.play();
                }
              });
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                VideoPlayer(_controller),
                if (!_controller.value.isPlaying)
                  Icon(Icons.play_circle_outline, size: 64, color: Colors.white.withOpacity(0.7)),
              ],
            ),
          )
        : Center(child: CircularProgressIndicator());
  }
}

class _TabText extends StatelessWidget {
  final String text;
  final bool selected;
  const _TabText(this.text, this.selected, {super.key});
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Roboto',
        fontWeight: FontWeight.w900,
        fontSize: 14,
        letterSpacing: 1.2,
        color: selected ? Colors.black : Colors.grey,
        decoration: selected ? TextDecoration.underline : null,
      ),
    );
  }
} 