import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class Character {
  final String name;
  final ImageProvider image;

  Character({required this.name, required this.image});
}

class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key});

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  final List<Character> _characters = [
    Character(
      name: 'サンプル2',
      image: const AssetImage('assets/images/Clogo.png'),
    ),
  ];

  final ImagePicker _picker = ImagePicker();

  void _addCharacter() async {
    String? name;
    XFile? pickedFile;
    ImageProvider? imageProvider;

    await showDialog(
      context: context,
      builder: (context) {
        final nameController = TextEditingController();
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('キャラクター追加'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () async {
                      pickedFile = await _picker.pickImage(source: ImageSource.gallery);
                      setStateDialog(() {});
                    },
                    child: CircleAvatar(
                      radius: 40,
                      backgroundImage: pickedFile != null
                          ? (pickedFile!.path.startsWith('http')
                              ? NetworkImage(pickedFile!.path)
                              : FileImage(File(pickedFile!.path)))
                          : const AssetImage('assets/images/Clogo.png') as ImageProvider,
                      child: pickedFile == null
                          ? const Icon(Icons.add_a_photo, color: Colors.white, size: 32)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: '名前'),
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
                    name = nameController.text.trim();
                    if (name != null && name!.isNotEmpty) {
                      imageProvider = pickedFile != null
                          ? (pickedFile!.path.startsWith('http')
                              ? NetworkImage(pickedFile!.path)
                              : FileImage(File(pickedFile!.path)))
                          : const AssetImage('assets/images/Clogo.png');
                      setState(() {
                        _characters.insert(0, Character(name: name!, image: imageProvider!));
                      });
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('追加'),
                ),
              ],
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
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
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
            ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 5, horizontal: 16),
              leading: CircleAvatar(
                backgroundImage: character.image,
                radius: 28,
              ),
              title: Text(character.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {},
            ),
            const SizedBox(height: 10),
          ],
        );
      },
    );
  }
} 