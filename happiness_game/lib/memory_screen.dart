import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'package:flutter/services.dart';

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

  final ImagePicker _picker = ImagePicker();

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
                  'chara',
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
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundImage: character.image,
                    radius: 28,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          character.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      if (character.subtitle != null && character.subtitle!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            character.subtitle!,
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                  Spacer(),
                  if (character.birthday != null && character.birthday!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 50, top: 6),
                      child: Text(
                        character.birthday!,
                        style: const TextStyle(fontSize: 11, color: Color(0xFFB0B0B0), fontWeight: FontWeight.w500),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
} 