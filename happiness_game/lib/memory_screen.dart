import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'home_screen.dart';
import 'dart:async';

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
    Uint8List? imageBytes;
    ImageProvider? imageProvider;
    String? subtitle;
    String? birthday;

    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.25),
      builder: (context) {
        final nameController = TextEditingController();
        final subtitleController = TextEditingController();
        final birthdayController = TextEditingController();
        String? errorText;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
              backgroundColor: Colors.white,
              elevation: 8,
              child: Container(
                width: 380,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 上部余白
                    const SizedBox(height: 8),
                    // 円形画像アップロード
                    GestureDetector(
                      onTap: () async {
                        pickedFile = await _picker.pickImage(source: ImageSource.gallery);
                        if (pickedFile != null) {
                          imageBytes = await pickedFile!.readAsBytes();
                        }
                        setStateDialog(() {});
                      },
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey[100],
                          border: Border.all(color: Colors.grey[400]!, width: 2),
                          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0,4))],
                        ),
                        child: imageBytes == null
                            ? Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Icon(Icons.add_a_photo_outlined, color: Colors.grey[600], size: 44),
                              )
                            : ClipOval(child: Image.memory(imageBytes!, fit: BoxFit.cover, width: 110, height: 110)),
                      ),
                    ),
                    const SizedBox(height: 18),
                    // 名前
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: nameController,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              hintText: '名前',
                              hintStyle: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.bold),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 0),
                            ),
                          ),
                        ),
                        Icon(Icons.edit, color: Colors.grey[500], size: 22),
                      ],
                    ),
                    Container(height: 1, color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    // サブ情報
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cake, color: Colors.grey[700], size: 20),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: birthdayController,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                            decoration: InputDecoration(
                              hintText: '誕生日 (例: 7/31)',
                              hintStyle: TextStyle(color: Colors.grey[400]),
                              border: InputBorder.none,
                            ),
                            keyboardType: TextInputType.datetime,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^[0-9/]*')),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Container(height: 1, color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.tag, color: Colors.grey[700], size: 20),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: subtitleController,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                            decoration: InputDecoration(
                              hintText: 'タグ (例: #アニメ名 #ニックネーム)',
                              hintStyle: TextStyle(color: Colors.grey[400]),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Container(height: 1, color: Colors.grey[300]),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey[800],
                              side: BorderSide(color: Colors.grey[400]!),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Colors.white,
                            ),
                            child: const Text('キャンセル', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              name = nameController.text.trim();
                              subtitle = subtitleController.text.trim();
                              birthday = birthdayController.text.trim();
                              String? error;
                              if (name == null || name?.isEmpty == true) {
                                error = '名前を入力してください';
                              } else if (subtitle == null || subtitle?.isEmpty == true) {
                                error = 'タグを入力してください';
                              } else if (birthday == null || birthday?.isEmpty == true) {
                                error = '誕生日を入力してください';
                              } else {
                                final match = RegExp(r'^(1[0-2]|[1-9])\/(3[01]|[12][0-9]|[1-9])').firstMatch(birthday!);
                                bool valid = false;
                                if (match != null) {
                                  final month = int.tryParse(match.group(1)!);
                                  final day = int.tryParse(match.group(2)!);
                                  if (month != null && day != null) {
                                    final daysInMonth = [0,31,28,31,30,31,30,31,31,30,31,30,31];
                                    if (month >= 1 && month <= 12 && day >= 1 && day <= daysInMonth[month]) {
                                      valid = true;
                                    }
                                  }
                                }
                                if (!valid) {
                                  error = '誕生日は実在する日付で 7/31 の形式で入力してください';
                                }
                              }
                              if (error != null) {
                                setStateDialog(() {
                                  errorText = error;
                                });
                                return;
                              }
                              imageProvider = imageBytes != null
                                  ? MemoryImage(imageBytes!)
                                  : const AssetImage('assets/images/Clogo.png');
                              setState(() {
                                _characters.insert(0, Character(name: name!, image: imageProvider!, subtitle: subtitle, birthday: birthday));
                                _filteredCharacters = List.from(_characters);
                              });
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[900],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text('登録', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),
                      ],
                    ),
                    if (errorText != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(errorText!, style: TextStyle(color: Colors.red, fontSize: 12)),
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
                            builder: (context) => CharacterDetailScreen(character: character),
                          ),
                        );
                      },
                      child: Row(
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

class CharacterDetailScreen extends StatelessWidget {
  final Character character;
  const CharacterDetailScreen({Key? key, required this.character}) : super(key: key);

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

  @override
  Widget build(BuildContext context) {
    final String birthdayEn = _formatBirthday(character.birthday);
    return Scaffold(
      backgroundColor: Color(0xFFB3E5FC),
      body: SafeArea(
        child: Stack(
          children: [
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
                        child: CircleAvatar(
                          backgroundImage: character.image,
                          radius: 50,
                          backgroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        character.name,
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
                            builder: (context) => MemoryGalleryScreen(character: character),
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
        ),
      ),
    );
  }
}

// --- ここからギャラリー画面を追加 ---
class MemoryGalleryScreen extends StatefulWidget {
  final Character character;
  const MemoryGalleryScreen({Key? key, required this.character}) : super(key: key);

  @override
  State<MemoryGalleryScreen> createState() => _MemoryGalleryScreenState();
}

class _MemoryGalleryScreenState extends State<MemoryGalleryScreen> {
  List<_MemoryPhoto> photos = [];

  void _addPhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;
    final imageBytes = await pickedFile.readAsBytes();
    String? title;
    String? hashtag;
    await showDialog(
      context: context,
      builder: (context) {
        final titleController = TextEditingController();
        final hashtagController = TextEditingController();
        return AlertDialog(
          title: const Text('写真アップロード'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.memory(imageBytes, width: 120, height: 120, fit: BoxFit.cover),
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
        photos.insert(0, _MemoryPhoto(imageBytes: imageBytes, title: title!, hashtag: hashtag ?? ''));
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
                          _TabText('ArtWork', true),
                          const SizedBox(width: 32),
                          _TabText('Almub', false),
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
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: photos.length,
              itemBuilder: (context, i) {
                final photo = photos[i];
                // 画像の縦横比でフレームを選択
                final image = Image.memory(photo.imageBytes);
                return FutureBuilder<Size>(
                  future: _getImageSize(photo.imageBytes),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const SizedBox(height: 200);
                    }
                    final size = snapshot.data!;
                    // long: 333.97x472, short: 336x201
                    final longFrame = const Size(333.97, 472);
                    final shortFrame = const Size(336, 201);
                    final double aspect = size.height / size.width;
                    final double longAspect = longFrame.height / longFrame.width;
                    final double shortAspect = shortFrame.height / shortFrame.width;
                    final bool useLong = (aspect - longAspect).abs() < (aspect - shortAspect).abs();
                    final frameAsset = useLong ? 'assets/images/long.png' : 'assets/images/short.png';
                    final frameSize = useLong ? longFrame : shortFrame;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 32, left: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              // 写真本体
                              ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Image.memory(
                                  photo.imageBytes,
                                  width: frameSize.width,
                                  height: frameSize.height,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              // フレーム画像を重ねる
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
                                padding: const EdgeInsets.only(left: 0, top: 9), // 5px左に寄せて3px下げる
                                child: CircleAvatar(
                                  backgroundImage: widget.character.image,
                                  radius: 22,
                                ),
                              ),
                              const SizedBox(width: 7),
                              const SizedBox(height: 0),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 12), // アイコン中心に揃えるための調整
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
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 画像サイズを取得するFuture
  Future<Size> _getImageSize(Uint8List bytes) async {
    final Completer<Size> completer = Completer();
    final img = Image.memory(bytes);
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
}

class _MemoryPhoto {
  final Uint8List imageBytes;
  final String title;
  final String hashtag;
  _MemoryPhoto({required this.imageBytes, required this.title, required this.hashtag});
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