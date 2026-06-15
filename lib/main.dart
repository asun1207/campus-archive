import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
// firebase_options.dart는 flutterfire cli를 통해 생성해야 합니다.
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/activity_screen.dart';
import 'screens/ai_counseling_screen.dart';
import 'screens/analysis_screen.dart';
import 'screens/mypage_screen.dart';

void main() async {
  // Flutter 엔진 초기화 보장
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 초기화 (실제 실행 시 firebase_options.dart 필요)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const CampusArchiveApp());
}

class CampusArchiveApp extends StatelessWidget {
  const CampusArchiveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Campus Archive',
      theme: ThemeData(
        // 메인 컬러: #4F46E5 (인디고)
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5)),
        primaryColor: const Color(0xFF4F46E5),
        useMaterial3: true,
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  // 5개의 탭 화면 리스트
  final List<Widget> _screens = [
    const HomeScreen(),
    const ActivityScreen(),
    const AiCounselingScreen(),
    const AnalysisScreen(),
    const MyPageScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // 4개 이상의 탭일 때 고정
        selectedItemColor: const Color(0xFF4F46E5), // 선택된 아이템 메인 컬러
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: '활동기록'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'AI상담'),
          BottomNavigationBarItem(icon: Icon(Icons.pie_chart_outline), label: '역량분석'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: '마이페이지'),
        ],
      ),
    );
  }
}