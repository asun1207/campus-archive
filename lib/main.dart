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
import 'screens/splash_view.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screens/profile_setup_screen.dart';

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
      // main.dart의 MaterialApp 내 home 부분 수정
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // 1. 앱이 로그인 상태를 확인하는 동안(초기 구동) Splash 화면 노출
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SplashScreen(); // 수정된 부분
          }

          // 2. 로그인된 유저 정보 존재 시 메인 화면 이동
          if (snapshot.hasData) {
            return const MainNavigationScreen();
          }

          // 3. 로그아웃 상태 시 로그인 화면 표시
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

    // 💡 화면이 그려진 직후, 프로필 정보가 있는지 확인
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndNavigateProfileSetup();
    });
  }

  // 프로필(학교명) 정보가 없으면 초기 설정 화면을 강제로 모달 띄우기
  Future<void> _checkAndNavigateProfileSetup() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (!doc.exists || doc.data()?['school'] == null || doc.data()?['school'] == '') {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ProfileSetupScreen(isEditing: false),
              fullscreenDialog: true, // 아래에서 위로 올라오는 모달 스타일
            ),
          );
        }
      }
    }
  }

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
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF4F46E5),
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