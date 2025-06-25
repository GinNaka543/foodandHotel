import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'home_screen.dart';

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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              backgroundColor: Colors.white,
              elevation: 8,
              child: Container(
                width: 340,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.style_outlined, color: Color(0xFF7C5CFC), size: 30),
                          const SizedBox(width: 8),
                          Text(
                            'キャラクター登録',
                            style: GoogleFonts.notoSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: Color(0xFF2D254C),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      GestureDetector(
                        onTap: () async {
                          pickedFile = await _picker.pickImage(source: ImageSource.gallery);
                          if (pickedFile != null) {
                            imageBytes = await pickedFile!.readAsBytes();
                          }
                          setStateDialog(() {});
                        },
                        child: Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Color(0xFF7C5CFC), width: 2),
                            color: const Color(0xFFF5F5FA),
                            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0,2))],
                          ),
                          child: imageBytes == null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_a_photo_outlined, color: Color(0xFF7C5CFC), size: 32),
                                    const SizedBox(height: 4),
                                    Text('画像アップロード',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Color(0xFF7C5CFC), fontWeight: FontWeight.bold, fontSize: 11)),
                                  ],
                                )
                              : ClipOval(child: Image.memory(imageBytes!, fit: BoxFit.cover, width: 90, height: 90)),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('名前', style: GoogleFonts.notoSans(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF2D254C))),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          hintText: '例：アスナ',
                          hintStyle: TextStyle(color: Color(0xFFBFAAFF)),
                          border: UnderlineInputBorder(),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF7C5CFC))),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('タグ', style: GoogleFonts.notoSans(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF2D254C))),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: subtitleController,
                        decoration: InputDecoration(
                          hintText: '#アニメ名 #ニックネーム',
                          hintStyle: TextStyle(color: Color(0xFFBFAAFF)),
                          border: UnderlineInputBorder(),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF7C5CFC))),
                        ),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF2D254C)),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('誕生日', style: GoogleFonts.notoSans(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF2D254C))),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: birthdayController,
                        decoration: InputDecoration(
                          hintText: '7/31',
                          hintStyle: TextStyle(color: Color(0xFFBFAAFF)),
                          border: UnderlineInputBorder(),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF7C5CFC))),
                        ),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF2D254C)),
                        keyboardType: TextInputType.datetime,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^[0-9/]*')),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ValueListenableBuilder(
                        valueListenable: birthdayController,
                        builder: (context, TextEditingValue value, _) {
                          final text = value.text;
                          bool valid = false;
                          if (text.isNotEmpty) {
                            final match = RegExp(r'^(1[0-2]|[1-9])\/(3[01]|[12][0-9]|[1-9])').firstMatch(text);
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
                          }
                          return !valid && text.isNotEmpty
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text('実在する日付で 月/日 の形式で入力してください', style: TextStyle(color: Colors.red, fontSize: 10)),
                                )
                              : const SizedBox.shrink();
                        },
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF7C5CFC),
                                side: const BorderSide(color: Color(0xFFBFAAFF)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('キャンセル', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
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
                              icon: const Icon(Icons.style_outlined, color: Colors.white),
                              label: const Text('キャラ登録', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7C5CFC),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
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
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // カスタムAppBar風ヘッダー
        SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 32), // ヘッダー上の空白を少し減らす
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 7, 16, 8), // 左paddingを増やし、topを少し減らす
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
        // キャラリストの上に広告風テキスト＋画像を追加（枠なし・大きめ画像・中央揃え）
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
                padding: const EdgeInsets.only(left: 16), // 画像を右にずらす
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
              // 誕生日やサブタイトル
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
                      CircleAvatar(
                        backgroundImage: character.image,
                        radius: 24,
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
                            const SizedBox(height: 2),
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
      ],
    );
  }
}

class CharacterDetailScreen extends StatelessWidget {
  final Character character;
  const CharacterDetailScreen({Key? key, required this.character}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // ダミー画像・動画リスト
    final List<ImageProvider> pictures = List.generate(4, (_) => character.image);
    final List<ImageProvider> videos = List.generate(6, (_) => character.image);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 背景画像
          Positioned.fill(
            child: Image(
              image: character.image,
              fit: BoxFit.cover,
              color: Colors.white.withOpacity(0.7),
              colorBlendMode: BlendMode.lighten,
            ),
          ),
          // 内容
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ヘッダー
                SizedBox(height: 48),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 26),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          character.name,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.search, color: Colors.black, size: 26),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: Icon(Icons.phone, color: Colors.black, size: 26),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: Icon(Icons.menu, color: Colors.black, size: 26),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 0),
                // PICTUREセクション
                Center(
                  child: Image.asset('assets/images/picture.png', width: 120, height: 120),
                ),
                const SizedBox(height: 8),
                // 画像カードリスト
                SizedBox(
                  height: 140,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: pictures.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (context, i) => Container(
                      width: 110,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0,2))],
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image(
                          image: pictures[i],
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // VIDEOセクション
                Center(
                  child: Image.asset('assets/images/video.png', width: 120, height: 120),
                ),
                const SizedBox(height: 8),
                // 動画カードリスト
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.2,
                    ),
                    itemCount: videos.length,
                    itemBuilder: (context, i) => Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0,2))],
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image(
                          image: videos[i],
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 下部ヘッダー
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 48),
              child: Row(
                children: [
                  Icon(Icons.add, size: 32),
                  const SizedBox(width: 8),
                  Icon(Icons.camera_alt_outlined, size: 28),
                  const SizedBox(width: 8),
                  Icon(Icons.image_outlined, size: 28),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Aa',
                                border: InputBorder.none,
                                hintStyle: TextStyle(color: Colors.grey, fontSize: 18),
                                isCollapsed: true,
                              ),
                            ),
                          ),
                          Icon(Icons.emoji_emotions_outlined, color: Colors.grey, size: 24),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.mic_none, size: 28),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 