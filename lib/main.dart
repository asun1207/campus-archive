import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 추가: Firebase Auth 패키지
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/activity_screen.dart';
import 'screens/ai_counseling_screen.dart';
import 'screens/analysis_screen.dart';
import 'screens/mypage_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  // Flutter 엔진 초기화 보장
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 초기화
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
      // StreamBuilder로 Firebase의 로그인 상태를 실시간 감지
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // 1. 앱이 로그인 상태를 확인하는 동안 보여줄 로딩 화면
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFF4F46E5),
              body: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            );
          }

          // 2. 로그인된 유저 정보가 존재하면(로그인 성공/유지) 메인 탭 화면으로 자동 이동
          if (snapshot.hasData) {
            return const MainNavigationScreen();
          }

          // 3. 유저 정보가 없으면(로그아웃 상태/최초 접속) 온보딩 화면 표시
          return const LoginScreen();
        },
      ),
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

  // 1. 멤버 변수로 한 번만 정의합니다.
  // 💡 여기서 _onItemTapped를 사용하려면 getter를 쓰거나 initState에서 초기화해야 하는데,
  // 더 간단한 방법은 'late' 키워드를 사용하는 것입니다.
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(onNavigateToTab: _onItemTapped),
      const ActivityScreen(),
      const AiCounselingScreen(),
      const AnalysisScreen(),
      const MyPageScreen(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 2. build 메서드 안의 중복 정의는 삭제하세요!
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