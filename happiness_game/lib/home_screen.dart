import 'package:flutter/material.dart';
import 'dart:ui'; // For BackdropFilter
import 'memory_screen.dart';

class HomeScreen extends StatefulWidget {
  final int selectedIndex;
  const HomeScreen({super.key, this.selectedIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _selectedIndex;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.selectedIndex;
  }

  @override
  Widget build(BuildContext context) {
    const double maxWidth = 400.0;
    const double navBarHeight = 95.0; // Custom NavBar height

    Widget body;
    if (_selectedIndex == 1) {
      body = const MemoryScreen();
    } else {
      body = Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: maxWidth),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, navBarHeight),
                  child: ListView(
                    children: [
                      const SizedBox(height: 32.0),
                      // 幸福度メーター
                      const Text(
                        '今日の幸福度',
                        style: TextStyle(fontSize: 18, color: Colors.black),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: 0.6, // 仮の値
                        minHeight: 10,
                        backgroundColor: Colors.grey[200],
                        color: Colors.black,
                      ),
                      const SizedBox(height: 24),
                      // 今週のクエスト
                      _buildQuestCard(
                        title: '今週のクエスト',
                        quests: [
                          '旅に出かけよう',
                          '美味しいもの探し',
                          '運動しよう',
                          'SNSやめよう',
                          '健康になろう'
                        ],
                      ),
                      const SizedBox(height: 24),
                      // 名言ガチャボタン
                      OutlinedButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: Colors.white,
                              title: const Text('今日の名言'),
                              content: const Text('「幸せはいつも自分の心が決める」'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('閉じる', style: TextStyle(color: Colors.black)),
                                ),
                              ],
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black,
                          side: const BorderSide(color: Colors.black),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(0),
                          ),
                        ),
                        child: const Text(
                          '名言ガチャを引く',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: body,
      bottomNavigationBar: _buildCustomBottomNavBar(),
    );
  }

  Widget _buildCustomBottomNavBar() {
    const double navBarHeight = 95.0;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          height: navBarHeight,
          color: const Color(0xFF1c1c1e).withOpacity(0.85),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNavItem(
                    imagePath: 'assets/images/clogo.png',
                    label: 'Home',
                    index: 0,
                  ),
                  _buildNavItem(
                    icon: Icons.person_outline,
                    label: 'Chara',
                    index: 1,
                  ),
                  _buildNavItem(
                    icon: Icons.list_alt_outlined,
                    label: 'List',
                    index: 2,
                  ),
                  _buildNavItem(
                    icon: Icons.style_outlined,
                    label: 'Create',
                    index: 3,
                  ),
                  _buildNavItem(
                    icon: Icons.swap_horiz_outlined,
                    label: 'Trade',
                    index: 4,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({String? imagePath, IconData? icon, required String label, required int index}) {
    final bool isSelected = _selectedIndex == index;
    final Color color = isSelected ? Colors.white : Colors.grey;
    const double defaultFontSize = 12.0;
    const double finalFontSize = defaultFontSize * 0.7;

    return Expanded(
      child: GestureDetector(
        onTap: () => _onItemTapped(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imagePath != null)
              ImageIcon(
                AssetImage(imagePath),
                color: color,
                size: 24,
              )
            else
              Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: finalFontSize,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestCard({required String title, required List<String> quests}) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          const SizedBox(height: 8),
          ...quests.map((quest) => Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Text('・$quest', style: const TextStyle(color: Colors.black)),
          )),
        ],
      ),
    );
  }
} 