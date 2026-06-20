import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  bool isSubscribed = false;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionStatus();
  }

  // 구독 상태 불러오기
  Future<void> _loadSubscriptionStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isSubscribed = prefs.getBool('isSubscribed') ?? false;
    });
  }

  // 로그아웃 처리
  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃 하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('확인')),
        ],
      ),
    );

    if (confirmed == true) {
      await GoogleSignIn.instance.signOut();
      await FirebaseAuth.instance.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('마이페이지', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: user == null
          ? Center(
        child: ElevatedButton(
          onPressed: () {}, // 로그인 화면으로 이동하는 로직 필요 시 연결
          child: const Text('로그인이 필요합니다'),
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 2. 프로필 영역
            CircleAvatar(
              radius: 40,
              backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
              child: user.photoURL == null ? const Icon(Icons.person, size: 40) : null,
            ),
            const SizedBox(height: 16),
            Text(user.displayName ?? '사용자', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(user.email ?? '', style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 24),

            // 3. 구독 플랜 카드
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(isSubscribed ? '프리미엄 이용 중 🎉' : '무료 플랜 이용 중',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (!isSubscribed)
                    ElevatedButton(
                      onPressed: () {}, // 추후 결제 연동
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white),
                      child: const Text('업그레이드'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 4. 활동 요약 (간단하게 하드코딩된 UI 예시)
            Row(
              children: [
                _buildSummaryItem('전체 활동', '12'),
                _buildSummaryItem('학기 수', '4'),
                _buildSummaryItem('태그 수', '28'),
              ],
            ),
            const SizedBox(height: 24),

            // 5. 메뉴 리스트
            _buildMenuTile(Icons.notifications_outlined, '알림 설정', () {}),
            _buildMenuTile(Icons.school_outlined, '학기 관리', () {}),
            _buildMenuTile(Icons.info_outline, '공지사항', () => _showDialog(context, '공지사항', '준비 중입니다.')),
            _buildMenuTile(Icons.apps, '앱 정보', () => _showDialog(context, '앱 정보', 'Campus Archive v1.0.0')),
            const Divider(),
            _buildMenuTile(Icons.logout, '로그아웃', () => _signOut(context)),

            const SizedBox(height: 40),
            const Text("Campus Archive — 나를 알면 길이 보인다", style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildMenuTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF4F46E5)),
      title: Text(title),
      onTap: onTap,
    );
  }

  void _showDialog(BuildContext context, String title, String content) {
    showDialog(context: context, builder: (context) => AlertDialog(title: Text(title), content: Text(content), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('닫기'))]));
  }
}