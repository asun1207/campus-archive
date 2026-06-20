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
  final Color primaryIndigo = const Color(0xFF4F46E5);
  bool isSubscribed = false;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionStatus();
  }

  // --- 1. 구독 상태 불러오기 ---
  Future<void> _loadSubscriptionStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isSubscribed = prefs.getBool('isSubscribed') ?? false;
    });
  }

// --- 2. 가상 결제 및 업그레이드/취소 처리 ---
  Future<void> _processUpgrade() async {
    // 현재 구독 중이면 취소 다이얼로그, 아니면 결제 다이얼로그 띄우기
    final title = isSubscribed ? '구독 취소' : '프리미엄 업그레이드';
    final content = isSubscribed ? '정말 프리미엄 구독을 해지하시겠습니까?' : '월 4,900원 결제를 진행하시겠습니까?\n\n(테스트: 확인을 누르면 즉시 전환됩니다)';
    final actionText = isSubscribed ? '해지하기' : '결제하기';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소', style: TextStyle(color: Colors.grey))
          ),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(actionText, style: TextStyle(color: isSubscribed ? Colors.red : primaryIndigo, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );

    // 확인 버튼을 눌렀을 때
    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();

      // 현재 상태의 반대로 전환 (구독 중이면 해지(false), 아니면 결제(true))
      final newValue = !isSubscribed;

      await prefs.setBool('isSubscribed', newValue);

      setState(() {
        isSubscribed = newValue;
      });

      if (mounted) {
        // 상태에 따라 알림 메시지도 다르게 출력!
        final message = newValue
            ? '🎉 프리미엄 구독이 완료되었습니다! AI 상담을 이용해보세요.'
            : '프리미엄 구독이 해지되어 무료 플랜으로 전환되었습니다.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }
  }

  // --- 3. 로그아웃 처리 ---
  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('정말 로그아웃 하시겠습니까?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소', style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('확인', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      await GoogleSignIn.instance.signOut();
      await FirebaseAuth.instance.signOut();
      // main.dart의 StreamBuilder가 로그아웃을 감지하고 자동으로 로그인 화면으로 돌려보냅니다.
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('마이페이지', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: user == null
          ? Center(
        child: Text('로그인 정보가 없습니다.', style: TextStyle(color: Colors.grey.shade600)),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 프로필 영역
            CircleAvatar(
              radius: 40,
              backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
              backgroundColor: primaryIndigo.withOpacity(0.1),
              child: user.photoURL == null ? Icon(Icons.person, size: 40, color: primaryIndigo) : null,
            ),
            const SizedBox(height: 16),
            Text(user.displayName ?? '사용자', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(user.email ?? '', style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 24),

            // 구독 플랜 카드
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isSubscribed ? primaryIndigo.withOpacity(0.1) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isSubscribed ? primaryIndigo.withOpacity(0.3) : Colors.grey.shade300),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSubscribed ? '프리미엄 이용 중 🎉' : '무료 플랜 이용 중',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isSubscribed ? primaryIndigo : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isSubscribed ? '모든 AI 기능을 무제한으로!' : 'AI 추천 기능이 잠겨있어요',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  if (!isSubscribed)
                    ElevatedButton(
                      onPressed: _processUpgrade, // 결제 로직 연결
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryIndigo,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('업그레이드', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // 활동 요약 (Firestore 실시간 연동)
            _buildRealtimeSummary(user.uid),
            const SizedBox(height: 32),

            // 메뉴 리스트
            _buildMenuTile(Icons.notifications_outlined, '알림 설정', () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('알림 설정 페이지로 이동합니다.')));
            }),
            _buildMenuTile(Icons.school_outlined, '학기 관리', () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('학기 관리 페이지로 이동합니다.')));
            }),
            _buildMenuTile(Icons.info_outline, '공지사항', () => _showDialog(context, '공지사항', '현재 등록된 공지사항이 없습니다.')),
            _buildMenuTile(Icons.apps, '앱 정보', () => _showDialog(context, '앱 정보', 'Campus Archive v1.0.0\n최신 버전입니다.')),
            const Divider(height: 32),
            // 로그아웃 버튼 바로 윗줄에 추가!
            if (isSubscribed) _buildMenuTile(Icons.cancel_outlined, '구독 해지', _processUpgrade),
            _buildMenuTile(Icons.logout, '로그아웃', () => _signOut(context), isDestructive: true),

            const SizedBox(height: 40),
            const Text("Campus Archive — 나를 알면 길이 보인다", style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- 4. Firestore 데이터 기반 실시간 요약 빌더 ---
  Widget _buildRealtimeSummary(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('activities')
          .where('userId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        int total = 0;
        int semesters = 0;
        int tags = 0;

        // 데이터를 성공적으로 불러왔을 때 통계 계산
        if (snapshot.hasData) {
          final docs = snapshot.data!.docs;
          total = docs.length;

          Set<String> semesterSet = {};
          Set<String> tagSet = {};

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['semester'] != null) semesterSet.add(data['semester']);

            final docTags = data['tags'] as List<dynamic>? ?? [];
            for (var t in docTags) {
              tagSet.add(t.toString().toUpperCase()); // 대소문자 무시하고 고유 태그 계산
            }
          }
          semesters = semesterSet.length;
          tags = tagSet.length;
        }

        return Row(
          children: [
            _buildSummaryItem('전체 활동', '$total'),
            _buildSummaryItem('학기 수', '$semesters'),
            _buildSummaryItem('태그 수', '$tags'),
          ],
        );
      },
    );
  }

  // 요약 아이템 UI
  Widget _buildSummaryItem(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryIndigo)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // 메뉴 타일 UI
  Widget _buildMenuTile(IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDestructive ? Colors.red.withOpacity(0.1) : primaryIndigo.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: isDestructive ? Colors.red : primaryIndigo, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: isDestructive ? Colors.red : Colors.black87,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
      onTap: onTap,
    );
  }

  // 팝업 다이얼로그
  void _showDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content, style: const TextStyle(height: 1.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('닫기', style: TextStyle(color: primaryIndigo, fontWeight: FontWeight.bold))
          )
        ],
      ),
    );
  }
}