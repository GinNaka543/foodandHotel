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
    String? filePath;
    String? webUrl;
    if (kIsWeb) {
      final result = await FilePicker.platform.pickFiles(type: FileType.video);
      if (result == null || result.files.isEmpty) return;
      final bytes = result.files.first.bytes;
      final name = result.files.first.name;
      if (bytes == null) return;
      final blob = html.Blob([bytes]);
      webUrl = html.Url.createObjectUrlFromBlob(blob);
    } else {
      final picker = ImagePicker();
      final pickedFile = await picker.pickVideo(source: ImageSource.gallery);
      if (pickedFile == null) return;
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = DateTime.now().millisecondsSinceEpoch.toString() + '_' + (pickedFile.name);
      final savePath = '${appDir.path}/$fileName';
      await File(pickedFile.path).copy(savePath);
      filePath = savePath;
    }
    String? title;
    String? hashtag;
    await showDialog(
      context: context,
      builder: (context) {
        final titleController = TextEditingController();
        final hashtagController = TextEditingController();
        return AlertDialog(
          title: const Text('動画アップロード'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: 369/222,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22.64),
                  child: kIsWeb
                    ? VideoPlayerPreviewWeb(url: webUrl!)
                    : VideoPlayerPreview(file: File(filePath!)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'タイトル'),
              ),
              TextField(
                controller: hashtagController,
                decoration: const InputDecoration(labelText: 'ハッシュタグ（例: #アニメ #感想）'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () {
                title = titleController.text.trim();
                hashtag = hashtagController.text.trim();
                if (title == null || title!.isEmpty) return;
                Navigator.pop(context);
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
    if (title != null && title!.isNotEmpty) {
      setState(() {
        videos.insert(0, _VideoItem(filePath: filePath, webUrl: webUrl, title: title!, hashtag: hashtag ?? ''));
      });
    }
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
                    GestureDetector(
                      onTap: _addVideo,
                      child: _TabText('Upload', false),
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
                      ClipRRect(
                        borderRadius: BorderRadius.circular(22.64),
                        child: SizedBox(
                          width: 369,
                          height: 222,
                          child: kIsWeb
                            ? VideoPlayerCardWeb(url: video.webUrl!)
                            : VideoPlayerCard(file: File(video.filePath!)),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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