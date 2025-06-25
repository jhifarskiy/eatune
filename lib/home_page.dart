import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_svg/flutter_svg.dart';

bool _burgerPressed = false;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int? selectedId;

  final List<Map<String, String>> tracks = List.generate(12, (index) {
    final id = (index + 1).toString();
    return {'id': id, 'title': 'Track $id', 'artist': 'Artist $id'};
  });

  Future<void> selectTrack(String id) async {
    final intId = int.tryParse(id);
    if (intId == null || intId < 1 || intId > 5) return;

    final url = Uri.parse('https://eatune-api.onrender.com/track');
    try {
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': intId}),
      );
      if (res.statusCode == 200) {
        setState(() => selectedId = intId);
      }
    } catch (e) {
      print('Ошибка: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Убираем backgroundColor из Scaffold, чтобы не перекрывал градиент
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF010A15), Color(0xFF0D325F)],
            stops: [0.0, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 130,
                  child: Stack(
                    children: [
                      // Бургер
                      Positioned(
                        left: 41,
                        top: 45,
                        child: GestureDetector(
                          onTapDown: (_) =>
                              setState(() => _burgerPressed = true),
                          onTapUp: (_) =>
                              setState(() => _burgerPressed = false),
                          onTapCancel: () =>
                              setState(() => _burgerPressed = false),
                          onTap: () {},
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 100),
                            transform: Matrix4.translationValues(
                              0,
                              _burgerPressed ? 4 : 0,
                              0,
                            ),
                            child: SvgPicture.asset(
                              'assets/icons/menu.svg',
                              color: Colors.white,
                              width: 30,
                              height: 24,
                            ),
                          ),
                        ),
                      ),

                      // Логотип строго по центру
                      Positioned(
                        top: 74,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: SvgPicture.asset(
                            'assets/icons/logo.svg',
                            width: 157,
                            height: 43,
                          ),
                        ),
                      ),

                      // Настройки
                      Positioned(
                        right: 42,
                        top: 36,
                        child: SvgPicture.asset(
                          'assets/icons/settings.svg',
                          color: Colors.white,
                          width: 33,
                          height: 33,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                const Text(
                  'NOW PLAYING',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.music_note, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sorry',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        Text(
                          'Justin Bieber',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Row(
                  children: [
                    Text('0:50', style: TextStyle(color: Colors.white54)),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: LinearProgressIndicator(
                          value: 0.3,
                          backgroundColor: Colors.white12,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Text('2:29', style: TextStyle(color: Colors.white54)),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    tabButton('POPULAR', true),
                    tabButton('BY GENRE', false),
                    tabButton('BY MOOD', false),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView.builder(
                    itemCount: tracks.length,
                    itemBuilder: (context, index) {
                      final track = tracks[index];
                      final isSelected = selectedId.toString() == track['id'];
                      return GestureDetector(
                        onTap: () => selectTrack(track['id']!),
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.audiotrack,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      track['title']!,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      track['artist']!,
                                      style: const TextStyle(
                                        color: Colors.white54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '0:50',
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.green
                                      : Colors.white60,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF041C3E),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white54,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.video_library), label: ''),
        ],
      ),
    );
  }

  Widget tabButton(String title, bool selected) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      decoration: BoxDecoration(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        title,
        style: TextStyle(
          color: selected ? const Color(0xFF041C3E) : Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
