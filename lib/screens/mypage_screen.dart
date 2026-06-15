import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  // 최신 7.x 버전에 맞춘 구글 로그인 함수
  Future<void> _signInWithGoogle() async {
    try {
      // 최신 구글 로그인 플러그인은 실행 전 초기화가 권장됩니다.
      await GoogleSignIn.instance.initialize();

      // 1. signIn() 대신 authenticate() 사용 및 GoogleSignIn.instance 사용
      final GoogleSignInAccount? googleUser = await GoogleSignIn.instance.authenticate();
      if (googleUser == null) return; // 사용자가 로그인을 취소한 경우

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 2. accessToken 없이 idToken만으로 Firebase 인증 (최신 버전 규격)
      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('구글 로그인에 성공했습니다!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그인 실패: $e')),
        );
      }
    }
  }

  // 로그아웃 함수
  Future<void> _signOut() async {
    // 3. GoogleSignIn() 대신 GoogleSignIn.instance 사용
    await GoogleSignIn.instance.signOut();
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('마이페이지')),
      // StreamBuilder로 로그인 상태를 실시간 감지
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final User? user = snapshot.data;

          // 로그인 상태일 때 (유저 정보 표시)
          if (user != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
                    child: user.photoURL == null ? const Icon(Icons.person, size: 40) : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                      '안녕하세요, ${user.displayName ?? '사용자'}님!',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
                  ),
                  const SizedBox(height: 8),
                  Text(user.email ?? ''),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _signOut,
                    child: const Text('로그아웃'),
                  ),
                ],
              ),
            );
          }

          // 비로그인 상태일 때 (로그인 버튼 표시)
          return Center(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.login),
              label: const Text('Google로 로그인'),
              onPressed: _signInWithGoogle,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5), // 인디고 메인 컬러
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          );
        },
      ),
    );
  }
}