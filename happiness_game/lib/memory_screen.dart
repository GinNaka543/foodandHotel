import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'home_screen.dart';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'video_gallery_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class Character {
  final String name;
  final ImageProvider image;
  final String? subtitle;
  final String? birthday;

  Character({required this.name, required this.image, this.subtitle, this.birthday});
}

class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key});

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  final List<Character> _characters = [
    Character(
      name: 'エル',
      image: const AssetImage('assets/images/sample.png'),
      subtitle: '#エルの手紙 #Lさま',
      birthday: '2/17',
    ),
  ];

  List<Character> _filteredCharacters = [];

  final ImagePicker _picker = ImagePicker();
  bool _showSearchBar = true;
  final TextEditingController _searchController = TextEditingController();

  // ダミー画像・動画リストを追加
  final List<ImageProvider> pictures = [
    const AssetImage('assets/images/sample.png'),
    const AssetImage('assets/images/sample.png'),
    const AssetImage('assets/images/sample.png'),
    const AssetImage('assets/images/sample.png'),
  ];
  
  final List<ImageProvider> videos = [
    const AssetImage('assets/images/sample.png'),
    const AssetImage('assets/images/sample.png'),
    const AssetImage('assets/images/sample.png'),
    const AssetImage('assets/images/sample.png'),
    const AssetImage('assets/images/sample.png'),
    const AssetImage('assets/images/sample.png'),
  ];

  @override
  void initState() {
    super.initState();
    _filteredCharacters = List.from(_characters);
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredCharacters = List.from(_characters);
      } else {
        _filteredCharacters = _characters.where((c) {
          final name = c.name.toLowerCase();
          final subtitle = (c.subtitle ?? '').toLowerCase();
          final birthday = (c.birthday ?? '').toLowerCase();
          return name.contains(query) || subtitle.contains(query) || birthday.contains(query);
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _addCharacter() async {
    String? name;
    XFile? pickedFile;
    String? subtitle;
    String? birthday;

    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) {
        final nameController = TextEditingController();
        final subtitleController = TextEditingController();
        final birthdayController = TextEditingController();
        String? errorText;
        String? savedPath;
        ImageProvider? imageProvider;
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
                    Text('写真アップロード', style: TextStyle(fontSize: 18, color: Colors.black, fontWeight: FontWeight.bold)),
                    SizedBox(height: 24),
                    GestureDetector(
                      onTap: () async {
                        if (kIsWeb) {
                          pickedFile = await _picker.pickImage(source: ImageSource.gallery);
                          if (pickedFile != null) {
                            final bytes = await pickedFile!.readAsBytes();
                            setStateDialog(() {
                              savedPath = null;
                              imageProvider = MemoryImage(bytes);
                            });
                          }
                        } else {
                          pickedFile = await _picker.pickImage(source: ImageSource.gallery);
                          if (pickedFile != null) {
                            final appDir = await getApplicationDocumentsDirectory();
                            final fileName = DateTime.now().millisecondsSinceEpoch.toString() + '_' + (pickedFile!.name);
                            final path = '${appDir.path}/$fileName';
                            await File(pickedFile!.path).copy(path);
                            setStateDialog(() {
                              savedPath = path;
                              imageProvider = FileImage(File(savedPath!));
                            });
                          }
                        }
                      },
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey[100],
                          border: Border.all(color: Colors.grey[300]!, width: 1),
                        ),
                        child: imageProvider == null
                            ? Icon(Icons.add_a_photo, color: Colors.grey[600], size: 32)
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image(
                                  image: imageProvider!,
                                  fit: BoxFit.cover,
                                  width: 80,
                                  height: 80,
                                ),
                              ),
                      ),
                    ),
                    SizedBox(height: 24),
                    TextField(
                      controller: nameController,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.black),
                      decoration: InputDecoration(
                        hintText: '名前',
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
                      controller: subtitleController,
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
                    SizedBox(height: 16),
                    TextField(
                      controller: birthdayController,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.black),
                      decoration: InputDecoration(
                        hintText: '誕生日（例: 2/17）',
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
                              name = nameController.text.trim();
                              subtitle = subtitleController.text.trim();
                              birthday = birthdayController.text.trim();
                              String? error;
                              final birthdayReg = RegExp(r'^(1[0-2]|0?[1-9])\/(3[01]|[12][0-9]|0?[1-9])$');
                              if (name == null || name!.isEmpty) {
                                error = '名前を入力してください';
                              } else if (subtitle == null || subtitle!.isEmpty) {
                                error = 'タグを入力してください';
                              } else if (imageProvider == null) {
                                error = '画像を選択してください';
                              } else if ((birthday?.isEmpty ?? true) || !birthdayReg.hasMatch(birthday ?? '')) {
                                error = '誕生日はMM/DD形式で入力してください';
                              }
                              if (error != null) {
                                setStateDialog(() {
                                  errorText = error;
                                });
                                return;
                              }
                              setState(() {
                                _characters.insert(0, Character(name: name!, image: imageProvider!, subtitle: subtitle, birthday: birthday));
                                _filteredCharacters = List.from(_characters);
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
    return Stack(
      children: [
        Column(
          children: [
            // カスタムAppBar風ヘッダー
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 7, 16, 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Chara',
                          style: GoogleFonts.notoSans(
                            fontWeight: FontWeight.w900,
                            fontSize: 24,
                            color: Colors.black,
                            letterSpacing: -1.2,
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, size: 32, color: Colors.black),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.format_list_bulleted),
                          onPressed: () {},
                          tooltip: 'リスト',
                        ),
                        IconButton(
                          icon: const Icon(Icons.image_outlined),
                          onPressed: () {},
                          tooltip: '画像',
                        ),
                        IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () {
                            setState(() {
                              _showSearchBar = !_showSearchBar;
                            });
                          },
                          tooltip: '検索',
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: _addCharacter,
                          tooltip: 'キャラクター追加',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // 検索バー
            if (_showSearchBar)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      Icon(Icons.search, color: Color(0xFFB0B0B0), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: TextStyle(fontSize: 14, color: Colors.black),
                          decoration: InputDecoration(
                            hintText: 'キャラクター名・タグ・誕生日で検索',
                            hintStyle: TextStyle(color: Color(0xFFB0B0B0), fontSize: 14),
                            border: InputBorder.none,
                            isCollapsed: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // キャラリストの上に広告風テキスト＋画像を追加
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '【スタバ新作✨】',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                '飲んでみた正直な感想',
                                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: Colors.black),
                              ),
                              const SizedBox(width: 4),
                              Text('😄', style: TextStyle(fontSize: 14)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Trending on LINE VOOM',
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: SizedBox(
                      width: 90,
                      height: 90,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          'assets/images/かのかり.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // キャラリスト
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                itemCount: _filteredCharacters.length,
                itemBuilder: (context, i) {
                  final character = _filteredCharacters[i];
                  final rightText = character.birthday ?? '';
                  final subtitle = character.subtitle ?? '';
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CharacterDetailScreen(character: character, pictures: pictures),
                          ),
                        );
                      },
                      child: Stack(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(width: 4),
                              Transform.translate(
                                offset: const Offset(0, -2),
                                child: CircleAvatar(
                                  backgroundImage: character.image,
                                  radius: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      character.name,
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.6, color: Colors.black),
                                    ),
                                    const SizedBox(height: 7),
                                    Text(
                                      subtitle,
                                      style: TextStyle(fontSize: 11.2, color: Colors.grey[700]),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                rightText,
                                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
        // ナビゲーションバーを絶対配置
        Positioned(
          left: 0,
          right: 0,
          bottom: 200,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    Icon(Icons.photo_library_outlined, color: Colors.white, size: 32),
                    const SizedBox(height: 4),
                    Text('Memory', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                Column(
                  children: [
                    Icon(Icons.play_circle_outline, color: Colors.white, size: 32),
                    const SizedBox(height: 4),
                    Text('Video', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                Column(
                  children: [
                    Icon(Icons.notes, color: Colors.white, size: 32),
                    const SizedBox(height: 4),
                    Text('About', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                Column(
                  children: [
                    Icon(Icons.directions_bus, color: Colors.white, size: 32),
                    const SizedBox(height: 4),
                    Text('Visit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
        ),
        // 下部に白い細い線を絶対配置（最下部から60px上）
        Positioned(
          left: 0,
          right: 0,
          bottom: 80,
          child: Container(
            width: double.infinity,
            height: 2.5,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class CharacterDetailScreen extends StatefulWidget {
  final Character character;
  final List<ImageProvider> pictures;
  const CharacterDetailScreen({Key? key, required this.character, required this.pictures}) : super(key: key);

  @override
  State<CharacterDetailScreen> createState() => _CharacterDetailScreenState();
}

class _CharacterDetailScreenState extends State<CharacterDetailScreen> {
  late ImageProvider _iconImage;
  late ImageProvider _backgroundImage;

  @override
  void initState() {
    super.initState();
    _iconImage = widget.character.image;
    _backgroundImage = widget.character.image;
  }

  String _formatBirthday(String? birthday) {
    if (birthday == null || !birthday.contains('/')) return '';
    final parts = birthday.split('/');
    if (parts.length != 2) return '';
    final month = int.tryParse(parts[0]);
    final day = int.tryParse(parts[1]);
    if (month == null || day == null) return '';
    const months = [
      '', 'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
    ];
    if (month < 1 || month > 12) return '';
    return '${months[month]}, $day';
  }

  Future<void> _showImageDialog({required bool isIcon}) async {
    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Image(
                  image: isIcon ? _iconImage : _backgroundImage,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              bottom: 150,
              child: ElevatedButton(
                onPressed: () async {
                  final ImagePicker picker = ImagePicker();
                  XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);
                  if (pickedFile != null) {
                    if (kIsWeb) {
                      final bytes = await pickedFile.readAsBytes();
                      setState(() {
                        if (isIcon) {
                          _iconImage = MemoryImage(bytes);
                        } else {
                          _backgroundImage = MemoryImage(bytes);
                        }
                      });
                    } else {
                      final appDir = await getApplicationDocumentsDirectory();
                      final fileName = DateTime.now().millisecondsSinceEpoch.toString() + '_' + (pickedFile.name);
                      final path = '${appDir.path}/$fileName';
                      await File(pickedFile.path).copy(path);
                      setState(() {
                        if (isIcon) {
                          _iconImage = FileImage(File(path));
                        } else {
                          _backgroundImage = FileImage(File(path));
                        }
                      });
                    }
                  }
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 32),
                  elevation: 0,
                ),
                child: const Text('写真を変更'),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String birthdayEn = _formatBirthday(widget.character.birthday);
    return Scaffold(
      backgroundColor: Color(0xFFB3E5FC),
      body: SafeArea(
        child: Stack(
          children: [
            // 背景画像
            GestureDetector(
              onTap: () => _showImageDialog(isIcon: false),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                child: Image(
                  image: _backgroundImage,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            // 既存のUI（アイコンや名前など）は上に重ねる
            Column(
              children: [
                // 戻るボタン
                const SizedBox(height: 48),
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 10.0),
                    child: IconButton(
                      icon: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                const Spacer(),
                // 中央の円形アイコン・名前・誕生日
                Center(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: GestureDetector(
                          onTap: () => _showImageDialog(isIcon: true),
                          child: CircleAvatar(
                            backgroundImage: _iconImage,
                            radius: 50,
                            backgroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.character.name,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          fontFamily: 'NotoSansJP',
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        birthdayEn,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                          letterSpacing: 2,
                          fontFamily: 'NotoSansJP',
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                const SizedBox(height: 80),
              ],
            ),
            // ナビゲーションバーを絶対配置
            Positioned(
              left: 0,
              right: 0,
              bottom: 200,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MemoryGalleryScreen(character: widget.character, pictures: widget.pictures),
                          ),
                        );
                      },
                      child: Column(
                        children: [
                          Icon(Icons.photo_library_outlined, color: Colors.white, size: 32),
                          const SizedBox(height: 4),
                          Text('Memory', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VideoGalleryScreen(character: widget.character),
                          ),
                        );
                      },
                      child: Column(
                        children: [
                          Icon(Icons.play_circle_outline, color: Colors.white, size: 32),
                          const SizedBox(height: 4),
                          Text('Video', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Icon(Icons.notes, color: Colors.white, size: 32),
                        const SizedBox(height: 4),
                        Text('About', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    Column(
                      children: [
                        Icon(Icons.directions_bus, color: Colors.white, size: 32),
                        const SizedBox(height: 4),
                        Text('Visit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // 下部に白い細い線を絶対配置（最下部から60px上）
            Positioned(
              left: 0,
              right: 0,
              bottom: 80,
              child: Container(
                width: double.infinity,
                height: 2.5,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- ここからギャラリー画面を追加 ---
class MemoryGalleryScreen extends StatefulWidget {
  final Character character;
  final List<ImageProvider> pictures;
  const MemoryGalleryScreen({Key? key, required this.character, required this.pictures}) : super(key: key);

  @override
  State<MemoryGalleryScreen> createState() => _MemoryGalleryScreenState();
}

class _MemoryGalleryScreenState extends State<MemoryGalleryScreen> {
  List<_MemoryPhoto> photos = [];
  int _selectedTab = 0;

  void _addPhoto() async {
    String? tempPath;
    Uint8List? webBytes;
    XFile? pickedFile;
    String? savedPath;
    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) {
        final titleController = TextEditingController();
        final hashtagController = TextEditingController();
        String? errorText;
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
                    Text('写真アップロード', style: TextStyle(fontSize: 18, color: Colors.black, fontWeight: FontWeight.bold)),
                    SizedBox(height: 24),
                    GestureDetector(
                      onTap: () async {
                        if (kIsWeb) {
                          final picker = ImagePicker();
                          pickedFile = await picker.pickImage(source: ImageSource.gallery);
                          if (pickedFile != null) {
                            final bytes = await pickedFile!.readAsBytes();
                            setStateDialog(() {
                              webBytes = bytes;
                            });
                          }
                        } else {
                          final picker = ImagePicker();
                          pickedFile = await picker.pickImage(source: ImageSource.gallery);
                          if (pickedFile != null) {
                            tempPath = pickedFile!.path;
                            setStateDialog(() {});
                          }
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
                        child: kIsWeb
                          ? (webBytes == null
                              ? Icon(Icons.add_a_photo, color: Colors.grey[600], size: 32)
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.memory(webBytes!, fit: BoxFit.cover, width: 80, height: 80)))
                          : (tempPath == null
                              ? Icon(Icons.add_a_photo, color: Colors.grey[600], size: 32)
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(File(tempPath!), fit: BoxFit.cover, width: 80, height: 80))),
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
                            onPressed: () async {
                              final title = titleController.text.trim();
                              final hashtag = hashtagController.text.trim();
                              String? error;
                              if (title.isEmpty) {
                                error = 'タイトルを入力してください';
                              } else if (hashtag.isEmpty) {
                                error = 'ハッシュタグを入力してください';
                              } else if ((kIsWeb && webBytes == null) || (!kIsWeb && tempPath == null)) {
                                error = '画像を選択してください';
                              }
                              if (error != null) {
                                setStateDialog(() {
                                  errorText = error;
                                });
                                return;
                              }
                              if (kIsWeb) {
                                setState(() {
                                  photos.insert(0, _MemoryPhoto(filePath: null, webBytes: webBytes, title: title, hashtag: hashtag));
                                });
                              } else {
                                final appDir = await getApplicationDocumentsDirectory();
                                final fileName = DateTime.now().millisecondsSinceEpoch.toString() + '_' + (pickedFile?.name ?? 'image.png');
                                savedPath = '${appDir.path}/$fileName';
                                await File(tempPath!).copy(savedPath!);
                                setState(() {
                                  photos.insert(0, _MemoryPhoto(filePath: savedPath, webBytes: null, title: title, hashtag: hashtag));
                                });
                              }
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
          actions: [
            // 右側のカメラマークはAppBarからは消すが、下のRowで表示する
          ],
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 100.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () => setState(() => _selectedTab = 0),
                            child: _TabText('ArtWork', _selectedTab == 0),
                          ),
                          const SizedBox(width: 32),
                          GestureDetector(
                            onTap: () => setState(() => _selectedTab = 1),
                            child: _TabText('Almub', _selectedTab == 1),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 15.0),
                      child: IconButton(
                        icon: const Icon(Icons.add_a_photo, color: Colors.black),
                        onPressed: _addPhoto,
                        tooltip: '写真をアップロード',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _selectedTab == 0
              ? // 従来のArtWorkリスト表示
                ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: photos.length,
                  itemBuilder: (context, i) {
                    final photo = photos[i];
                    if (kIsWeb) {
                      // WebはImage.memoryのみ
                      final longFrame = const Size(334, 472);
                      final shortFrame = const Size(336, 201);
                      return FutureBuilder<Size?>(
                        future: photo.webBytes != null ? _getImageSizeFromBytes(photo.webBytes!) : Future.value(null),
                        builder: (context, snapshot) {
                          final imageSize = snapshot.data;
                          final frameSize = (imageSize != null)
                              ? (() {
                                  final aspect = imageSize.height / imageSize.width;
                                  final longAspect = longFrame.height / longFrame.width;
                                  final shortAspect = shortFrame.height / shortFrame.width;
                                  return (aspect - longAspect).abs() < (aspect - shortAspect).abs() ? longFrame : shortFrame;
                                })()
                              : shortFrame;
                          return Stack(
                            children: [
                              Container(
                                margin: const EdgeInsets.only(bottom: 32, left: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: photo.webBytes == null
                                          ? Container(width: frameSize.width, height: frameSize.height)
                                          : Image.memory(photo.webBytes!, width: frameSize.width, height: frameSize.height, fit: BoxFit.cover),
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
                                                  photo.title,
                                                  style: const TextStyle(
                                                    fontFamily: 'NotoSansJP',
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 15,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                                if (photo.hashtag.isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 2.0),
                                                    child: Text(
                                                      photo.hashtag,
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
                              ),
                            ],
                          );
                        },
                      );
                    } else {
                      // モバイルはFutureBuilder＋Image.file
                      return FutureBuilder<Size>(
                        future: _getImageSizeFromFile(photo.filePath!),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const SizedBox(height: 200);
                          }
                          final size = snapshot.data!;
                          final longFrame = const Size(334, 472);
                          final shortFrame = const Size(336, 201);
                          final double aspect = size.height / size.width;
                          final double longAspect = longFrame.height / longFrame.width;
                          final double shortAspect = shortFrame.height / shortFrame.width;
                          final bool useLong = (aspect - longAspect).abs() < (aspect - shortAspect).abs();
                          final frameAsset = useLong ? 'assets/images/long.png' : 'assets/images/short.png';
                          final frameSize = useLong ? longFrame : shortFrame;
                          return Stack(
                            children: [
                              Container(
                                margin: const EdgeInsets.only(bottom: 32, left: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(20),
                                          child: Image.file(
                                            File(photo.filePath!),
                                            width: frameSize.width,
                                            height: frameSize.height,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        Image.asset(
                                          frameAsset,
                                          width: frameSize.width,
                                          height: frameSize.height,
                                          fit: BoxFit.cover,
                                        ),
                                      ],
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
                                                  photo.title,
                                                  style: const TextStyle(
                                                    fontFamily: 'NotoSansJP',
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 15,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                                if (photo.hashtag.isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 2.0),
                                                    child: Text(
                                                      photo.hashtag,
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
                              ),
                            ],
                          );
                        },
                      );
                    }
                  },
                )
              : // Almubタブ: artwork画像リスト（pictures）をGrid表示
                GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1,
                  ),
                  itemCount: photos.length,
                  itemBuilder: (context, i) {
                    final photo = photos[i];
                    return Stack(
                      children: [
                        GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => Dialog(
                                backgroundColor: Colors.black,
                                child: InteractiveViewer(
                                  child: photo.webBytes != null
                                    ? Image.memory(photo.webBytes!, fit: BoxFit.contain)
                                    : Image.file(File(photo.filePath!), fit: BoxFit.contain),
                                ),
                              ),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: photo.webBytes != null
                                ? Image.memory(photo.webBytes!, fit: BoxFit.cover)
                                : Image.file(File(photo.filePath!), fit: BoxFit.cover),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }

  Future<Size> _getImageSizeFromFile(String filePath) async {
    final Completer<Size> completer = Completer();
    final img = Image.file(File(filePath));
    img.image.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((ImageInfo info, bool _) {
        final mySize = Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        );
        completer.complete(mySize);
      }),
    );
    return completer.future;
  }

  Future<Size?> _getImageSizeFromBytes(Uint8List bytes) async {
    final completer = Completer<Size>();
    final img = Image.memory(bytes);
    img.image.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((ImageInfo info, bool _) {
        completer.complete(Size(info.image.width.toDouble(), info.image.height.toDouble()));
      }),
    );
    return completer.future;
  }
}

class _MemoryPhoto {
  final String? filePath;
  final Uint8List? webBytes;
  final String title;
  final String hashtag;
  _MemoryPhoto({this.filePath, this.webBytes, required this.title, required this.hashtag});
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

class AlbumScreen extends StatelessWidget {
  final Character character;
  final List<ImageProvider> pictures;
  const AlbumScreen({Key? key, required this.character, required this.pictures}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          '${character.name}のAlbum',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      backgroundColor: Colors.white,
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1,
        ),
        itemCount: pictures.length,
        itemBuilder: (context, i) {
          return GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => Dialog(
                  backgroundColor: Colors.black,
                  child: InteractiveViewer(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Image(
                        image: pictures[i],
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 1,
                child: Image(
                  image: pictures[i],
                  fit: BoxFit.cover,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
} 