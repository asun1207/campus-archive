import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_activity_screen.dart'; // FAB 클릭 시 이동할 화면

class HomeScreen extends StatefulWidget {
  final Function(int) onNavigateToTab; // 탭 이동 콜백 추가
  const HomeScreen({super.key, required this.onNavigateToTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Color primaryIndigo = const Color(0xFF4F46E5);
  final Color lightIndigo = const Color(0xFFEEF2FF);

  final User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Campus Archive',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: Colors.black87),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('새로운 알림이 없습니다.')),
              );
            },
          ),
        ],
      ),
      body: currentUser == null
          ? const Center(child: Text('로그인 정보가 없습니다.'))
          : _buildHomeContent(),

      // 우하단 플로팅 액션 버튼 (FAB)
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // 활동 등록 화면으로 이동
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddActivityScreen()),
          );
        },
        backgroundColor: primaryIndigo,
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  // --- 메인 콘텐츠 (StreamBuilder) ---
  Widget _buildHomeContent() {
    return StreamBuilder<QuerySnapshot>(
      // 현재 유저의 전체 활동 기록을 최신순으로 가져오기
      stream: FirebaseFirestore.instance
          .collection('activities')
          .where('userId', isEqualTo: currentUser!.uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: primaryIndigo));
        }

        if (snapshot.hasError) {
          return const Center(child: Text('데이터를 불러오는 중 오류가 발생했습니다.'));
        }

        final docs = snapshot.data?.docs ?? [];

        // 데이터 집계 로직
        int totalActivities = docs.length;
        int subjectCount = docs.where((doc) => (doc.data() as Map<String, dynamic>)['category'] == '수강 과목').length;

        Set<String> uniqueTags = {};
        for (var doc in docs) {
          final tags = (doc.data() as Map<String, dynamic>)['tags'] ?? [];
          for (var tag in tags) {
            uniqueTags.add(tag.toString());
          }
        }
        int tagCount = uniqueTags.length;

        // 최근 기록 5개 추출
        final recentDocs = docs.take(5).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 인사 배너
              _buildGreetingBanner(),
              const SizedBox(height: 32),

              // 2. 활동 요약 카드 (3칸 나란히)
              const Text(
                '내 활동 요약',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 16),
              _buildSummaryCards(totalActivities, subjectCount, tagCount),
              const SizedBox(height: 40),

              // 3. 최근 기록 섹션
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '최근 기록',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  if (recentDocs.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        widget.onNavigateToTab(1); // 활동기록 탭의 인덱스가 1이므로 1을 전달
                      },
                      child: Text('더보기', style: TextStyle(color: primaryIndigo, fontWeight: FontWeight.w600)),
                    )
                ],
              ),
              const SizedBox(height: 12),

              // 최근 기록 리스트 렌더링
              if (recentDocs.isEmpty)
                _buildEmptyRecentState()
              else
                ...recentDocs.map((doc) => _buildRecentCard(doc)).toList(),

              const SizedBox(height: 80), // FAB에 가리지 않도록 하단 여백 추가
            ],
          ),
        );
      },
    );
  }

  // --- UI 컴포넌트: 인사 배너 ---
  Widget _buildGreetingBanner() {
    final userName = currentUser?.displayName ?? '사용자';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: lightIndigo,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '안녕하세요, $userName님! 👋',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '오늘도 한 줄 기록해볼까요?',
            style: TextStyle(
              fontSize: 15,
              color: primaryIndigo.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // --- UI 컴포넌트: 활동 요약 카드 ---
  Widget _buildSummaryCards(int total, int subjects, int tags) {
    return Row(
      children: [
        _buildSingleSummaryCard('전체 활동', '$total', Icons.assignment_outlined),
        const SizedBox(width: 12),
        _buildSingleSummaryCard('수강 과목', '$subjects', Icons.menu_book_rounded),
        const SizedBox(width: 12),
        _buildSingleSummaryCard('태그 종류', '$tags', Icons.local_offer_outlined),
      ],
    );
  }

  Widget _buildSingleSummaryCard(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: primaryIndigo.withOpacity(0.6), size: 24),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(fontSize: 22, color: primaryIndigo, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI 컴포넌트: 데이터가 없을 때의 최근 기록 상태 ---
  Widget _buildEmptyRecentState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.edit_document, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            '아직 기록된 활동이 없어요',
            style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // --- UI 컴포넌트: 최근 기록 개별 카드 ---
  Widget _buildRecentCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final title = data['title'] ?? '제목 없음';
    final date = data['date'] ?? '';
    final category = data['category'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddActivityScreen(activityDoc: doc),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 카테고리 아이콘 영역
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaryIndigo.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  category == '수강 과목' ? Icons.menu_book_rounded :
                  category == '교내 활동' ? Icons.school_rounded : Icons.public_rounded,
                  color: primaryIndigo,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),

              // 텍스트 영역
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$category • $date',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),

              // 우측 화살표
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}