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
      // 💡 여기서부터 변경됨: Minimal SaaS 디자인 시스템 전역 테마 적용
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8F9FE), // 부드러운 틴트가 들어간 배경색
        primaryColor: const Color(0xFF4F46E5),

        // 전체적인 색상 위계 정의
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F46E5),
          background: const Color(0xFFF8F9FE),
          surface: Colors.white,
          onSurface: const Color(0xFF1E1B4B), // 깊은 밀도의 텍스트 컬러
        ),

        // 앱바 디자인의 SaaS 표준화 (선 없애고 배경과 투명하게 동화)
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF8F9FE),
          elevation: 0,
          iconTheme: IconThemeData(color: Color(0xFF1E1B4B)),
          titleTextStyle: TextStyle(
            color: Color(0xFF1E1B4B),
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),

        // 텍스트 위계(Typography Scale) 설정
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E1B4B), letterSpacing: -0.8),
          titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E1B4B), letterSpacing: -0.5),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1E1B4B), letterSpacing: -0.3),
          bodyLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.normal, color: Color(0xFF374151), height: 1.5),
          bodyMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.normal, color: Color(0xFF6B7280)),
        ),

        // 입력 필드(TextField)의 모던한 테두리 양식 통일
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
          ),
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        ),
      ),
      // 💡 여기까지 테마 설정 끝

      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SplashScreen();
          }
          if (snapshot.hasData) {
            return const MainNavigationScreen();
          }
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndNavigateProfileSetup();
    });
  }

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
              fullscreenDialog: true,
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
        backgroundColor: Colors.white, // 네비게이션 바 배경색 명시
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