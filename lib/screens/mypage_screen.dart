import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'semester_management_screen.dart';
import 'profile_setup_screen.dart';

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

  Future<void> _loadSubscriptionStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isSubscribed = prefs.getBool('isSubscribed') ?? false;
    });
  }

  Future<void> _processUpgrade() async {
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소', style: TextStyle(color: Colors.grey))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(actionText, style: TextStyle(color: isSubscribed ? Colors.red : primaryIndigo, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      final newValue = !isSubscribed;

      await prefs.setBool('isSubscribed', newValue);

      setState(() {
        isSubscribed = newValue;
      });

      if (mounted) {
        final message = newValue ? '🎉 프리미엄 구독이 완료되었습니다! AI 상담을 이용해보세요.' : '프리미엄 구독이 해지되어 무료 플랜으로 전환되었습니다.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

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
          ? Center(child: Text('로그인 정보가 없습니다.', style: TextStyle(color: Colors.grey.shade600)))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 💡 프로필 영역 연동 (다중전공 배지 + 동기부여 꿈 한 줄 요약 포함 버전)
            StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
                builder: (context, snapshot) {
                  String schoolName = '학교 정보 없음';
                  String gradeInfo = '';
                  String dreamText = ''; // 💡 꿈 저장용 변수
                  List<Widget> majorWidgets = [const Text('프로필을 설정해주세요', style: TextStyle(color: Colors.grey, fontSize: 13))];

                  if (snapshot.hasData && snapshot.data!.exists) {
                    final data = snapshot.data!.data() as Map<String, dynamic>?;
                    if (data != null) {
                      schoolName = data['school'] ?? '학교 정보 없음';
                      gradeInfo = data['grade'] != null ? ' • ${data['grade']}' : '';
                      dreamText = data['dream'] ?? ''; // 💡 꿈 문자열 추출

                      final List<dynamic>? savedMajors = data['majors'];
                      if (savedMajors != null && savedMajors.isNotEmpty) {
                        majorWidgets = savedMajors.map((m) {
                          final String type = m['type'] ?? '주전공';
                          final String name = m['name'] ?? '';
                          final isMain = type == '주전공';
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isMain ? primaryIndigo.withOpacity(0.08) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: isMain ? primaryIndigo.withOpacity(0.2) : Colors.grey.shade300),
                            ),
                            child: Text(
                              '[$type] $name',
                              style: TextStyle(fontSize: 12, fontWeight: isMain ? FontWeight.bold : FontWeight.normal, color: isMain ? primaryIndigo : Colors.black87),
                            ),
                          );
                        }).toList();
                      }
                    }
                  }

                  return Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
                        backgroundColor: primaryIndigo.withOpacity(0.1),
                        child: user.photoURL == null ? Icon(Icons.person, size: 40, color: primaryIndigo) : null,
                      ),
                      const SizedBox(height: 16),
                      Text(user.displayName ?? '사용자', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('$schoolName$gradeInfo', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                      const SizedBox(height: 8),
                      Wrap(alignment: WrapAlignment.center, spacing: 4, runSpacing: 4, children: majorWidgets),

                      // 💡 [신규] 동기부여 꿈 카드 렌더링 영역
                      if (dreamText.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F3FF), // 아주 부드러운 인디고 연보라 배경
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: primaryIndigo.withOpacity(0.1)),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.format_quote_rounded, color: primaryIndigo.withOpacity(0.3), size: 24),
                              Text(
                                dreamText,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: primaryIndigo.withOpacity(0.9),
                                    height: 1.5,
                                    fontStyle: FontStyle.italic
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(user.email ?? '', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ],
                  );
                }
            ),
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
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isSubscribed ? primaryIndigo : Colors.black87),
                      ),
                      const SizedBox(height: 4),
                      Text(isSubscribed ? '모든 AI 기능을 무제한으로!' : 'AI 추천 기능이 잠겨있어요', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                  if (!isSubscribed)
                    ElevatedButton(
                      onPressed: _processUpgrade,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryIndigo, foregroundColor: Colors.white,
                        elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
            _buildMenuTile(Icons.person_outline, '프로필 수정', () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileSetupScreen(isEditing: true)));
            }),
            _buildMenuTile(Icons.notifications_outlined, '알림 설정', () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('알림 설정 페이지로 이동합니다.')));
            }),
            _buildMenuTile(Icons.school_outlined, '학기 관리', () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const SemesterManagementScreen()));
            }),
            _buildMenuTile(Icons.info_outline, '공지사항', () => _showDialog(context, '공지사항', '현재 등록된 공지사항이 없습니다.')),
            _buildMenuTile(Icons.apps, '앱 정보', () => _showDialog(context, '앱 정보', 'Campus Archive v1.0.0\n최신 버전입니다.')),
            const Divider(height: 32),

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

  Widget _buildRealtimeSummary(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('activities').where('userId', isEqualTo: userId).snapshots(),
      builder: (context, snapshot) {
        int total = 0; int semesters = 0; int tags = 0;
        if (snapshot.hasData) {
          final docs = snapshot.data!.docs;
          total = docs.length;
          Set<String> semesterSet = {}; Set<String> tagSet = {};
          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['semester'] != null) semesterSet.add(data['semester']);
            final docTags = data['tags'] as List<dynamic>? ?? [];
            for (var t in docTags) {
              tagSet.add(t.toString().toUpperCase());
            }
          }
          semesters = semesterSet.length; tags = tagSet.length;
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
      title: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: isDestructive ? Colors.red : Colors.black87)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
      onTap: onTap,
    );
  }

  void _showDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content, style: const TextStyle(height: 1.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('닫기', style: TextStyle(color: primaryIndigo, fontWeight: FontWeight.bold)))],
      ),
    );
  }
}