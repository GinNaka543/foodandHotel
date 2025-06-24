import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';

class Character {
  final String name;
  final ImageProvider image;
  final String? subtitle;

  Character({required this.name, required this.image, this.subtitle});
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
      subtitle: 'サンプルの説明',
    ),
  ];

  final ImagePicker _picker = ImagePicker();

  void _addCharacter() async {
    String? name;
    XFile? pickedFile;
    Uint8List? imageBytes;
    ImageProvider? imageProvider;
    String? subtitle;

    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.2),
      builder: (context) {
        final nameController = TextEditingController();
        final subtitleController = TextEditingController();
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              backgroundColor: const Color(0xFFF7F3FF),
              child: Container(
                width: 320,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: const [
                          Icon(Icons.emoji_symbols, color: Color(0xFF9B7BFF), size: 28),
                          Text(
                            'キャラクターを追加しよう！',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Color(0xFF2D254C),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: () async {
                          pickedFile = await _picker.pickImage(source: ImageSource.gallery);
                          if (pickedFile != null) {
                            imageBytes = await pickedFile!.readAsBytes();
                          }
                          setStateDialog(() {});
                        },
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Color(0xFFBFAAFF), width: 2),
                            color: const Color(0xFFEDE7F6),
                          ),
                          child: imageBytes == null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.add, color: Color(0xFF9B7BFF), size: 36),
                                    SizedBox(height: 4),
                                    Text('画像\nアップロード',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Color(0xFF9B7BFF), fontWeight: FontWeight.bold, fontSize: 11)),
                                  ],
                                )
                              : ClipOval(child: Image.memory(imageBytes!, fit: BoxFit.cover, width: 100, height: 100)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: const Text('名前:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2D254C))),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          hintText: '例：アスナ',
                          hintStyle: TextStyle(color: Color(0xFFBFAAFF)),
                          border: UnderlineInputBorder(),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF9B7BFF))),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: subtitleController,
                        decoration: const InputDecoration(
                          hintText: 'メモや説明（任意）',
                          hintStyle: TextStyle(color: Colors.grey),
                          border: UnderlineInputBorder(),
                        ),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF9B7BFF),
                                side: const BorderSide(color: Color(0xFFBFAAFF)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                                if (name != null && name!.isNotEmpty) {
                                  imageProvider = imageBytes != null
                                      ? MemoryImage(imageBytes!)
                                      : const AssetImage('assets/images/Clogo.png');
                                  setState(() {
                                    _characters.insert(0, Character(name: name!, image: imageProvider!, subtitle: subtitle));
                                  });
                                  Navigator.pop(context);
                                }
                              },
                              icon: const Icon(Icons.emoji_symbols, color: Colors.white),
                              label: const Text('キャラ登録', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF9B7BFF),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ],
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
    return ListView.builder(
      padding: const EdgeInsets.only(top: 48),
      itemCount: _characters.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          // ヘッダー部分
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Chats',
                  style: GoogleFonts.changa(
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down, size: 32, color: Colors.black),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.format_list_bulleted, color: Colors.black),
                  onPressed: () {},
                  tooltip: 'リスト',
                ),
                IconButton(
                  icon: const Icon(Icons.image_outlined, color: Colors.black),
                  onPressed: () {},
                  tooltip: '画像',
                ),
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline, color: Colors.black),
                  onPressed: () {},
                  tooltip: '吹き出し',
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: Colors.black),
                  onPressed: _addCharacter,
                  tooltip: 'キャラクター追加',
                ),
              ],
            ),
          );
        }
        final character = _characters[index - 1];
        return Column(
          children: [
            const SizedBox(height: 20),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              minVerticalPadding: 0,
              leading: CircleAvatar(
                backgroundImage: character.image,
                radius: 28,
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      character.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  if (character.subtitle != null && character.subtitle!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        character.subtitle!,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
              onTap: () {},
            ),
            const SizedBox(height: 10),
          ],
        );
      },
    );
  }
} 