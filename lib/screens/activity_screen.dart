import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_activity_screen.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  // 앱 메인 컬러 적용
  final Color primaryIndigo = const Color(0xFF4F46E5);

  // 가상의 학기 리스트 (추후 Firestore에서 동적으로 불러오도록 확장 가능)
  final List<String> _semesters = ['2026-1학기', '2025-2학기', '2025-1학기', '2024-2학기'];
  String _selectedSemester = '2026-1학기';

  // 현재 로그인한 유저 정보
  final User? currentUser = FirebaseAuth.instance.currentUser;

  // 플로팅 액션 버튼이나 상단 + 버튼에서 호출할 등록 화면 이동 함수 (임시 빈 함수)
  void _navigateToAddActivity() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddActivityScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '활동 기록',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: primaryIndigo, size: 28),
            onPressed: _navigateToAddActivity,
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. 학기 탭 (가로 스크롤)
          _buildSemesterTabs(),

          // 2. 활동 리스트 영역 (실시간 Firestore 연동)
          Expanded(
            child: _buildActivityStream(),
          ),
        ],
      ),
    );
  }

  // --- UI 컴포넌트: 학기 탭 ---
  Widget _buildSemesterTabs() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _semesters.length,
        itemBuilder: (context, index) {
          final semester = _semesters[index];
          final isSelected = semester == _selectedSemester;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedSemester = semester;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? primaryIndigo : Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  semester,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black54,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- 데이터 패칭: Firestore 실시간 스트림 ---
  Widget _buildActivityStream() {
    if (currentUser == null) {
      return const Center(child: Text('로그인이 필요합니다.'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('activities')
          .where('userId', isEqualTo: currentUser!.uid)
          .where('semester', isEqualTo: _selectedSemester)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: primaryIndigo));
        }

        if (snapshot.hasError) {
          return Center(child: Text('데이터를 불러오는 중 오류가 발생했습니다.\n${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];

        // 데이터가 아예 없을 때의 빈 상태(Empty State) UI
        if (docs.isEmpty) {
          return _buildEmptyState();
        }

        // 카테고리별로 데이터 분류
        final classActivities = docs.where((doc) => doc['category'] == '수강 과목').toList();
        final schoolActivities = docs.where((doc) => doc['category'] == '교내 활동').toList();
        final outsideActivities = docs.where((doc) => doc['category'] == '대외 활동').toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (classActivities.isNotEmpty)
              _buildCategorySection('📚 수강 과목', classActivities),
            if (schoolActivities.isNotEmpty)
              _buildCategorySection('🏫 교내 활동', schoolActivities),
            if (outsideActivities.isNotEmpty)
              _buildCategorySection('🌐 대외 활동', outsideActivities),
          ],
        );
      },
    );
  }

  // --- UI 컴포넌트: 빈 상태 (Empty State) ---
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_rounded, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            '아직 기록이 없어요',
            style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _navigateToAddActivity,
            icon: const Icon(Icons.edit),
            label: const Text('기록 추가하기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryIndigo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          )
        ],
      ),
    );
  }

  // --- UI 컴포넌트: 카테고리별 섹션 ---
  Widget _buildCategorySection(String title, List<QueryDocumentSnapshot> activities) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 카테고리 타이틀 및 개수
          Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 4),
            child: Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: primaryIndigo.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${activities.length}',
                    style: TextStyle(
                      color: primaryIndigo,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 활동 카드 리스트
          ...activities.map((doc) => _buildActivityCard(doc)).toList(),
        ],
      ),
    );
  }

  // --- UI 컴포넌트: 활동 기록 카드 ---
  Widget _buildActivityCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final title = data['title'] ?? '제목 없음';
    final date = data['date'] ?? '';
    final List<dynamic> tags = data['tags'] ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // TODO: 상세 및 수정 화면으로 이동
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('[$title] 상세 화면으로 이동합니다.')),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 카드 제목
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),

              // 태그 (Wrap을 사용하여 줄바꿈 자연스럽게 처리)
              if (tags.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: tags.map((tag) {
                    return Chip(
                      label: Text(
                        '#$tag',
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      backgroundColor: Colors.grey.shade100,
                      side: BorderSide.none,
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],

              // 날짜 표시
              Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    date,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}