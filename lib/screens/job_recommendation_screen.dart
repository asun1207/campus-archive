import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class JobRecommendationScreen extends StatefulWidget {
  const JobRecommendationScreen({super.key});

  @override
  State<JobRecommendationScreen> createState() => _JobRecommendationScreenState();
}

class _JobRecommendationScreenState extends State<JobRecommendationScreen> {
  final Color primaryIndigo = const Color(0xFF4F46E5);
  bool _isSubscribed = false;
  bool _isLoading = true;
  List<String> _userTags = [];

  // 매핑 테이블
  final List<Map<String, dynamic>> _jobMappings = [
    {
      'jobTitle': '서비스 기획자 / PM',
      'keywords': ['기획', '커뮤니케이션', '리더십', '프로젝트관리'],
      'reason': '기획 및 소통 역량이 돋보입니다. 프로젝트의 방향을 이끄는 PM 직무에 적합해요.',
      'lacking': ['데이터분석', 'UI/UX이해']
    },
    {
      'jobTitle': '데이터 분석가',
      'keywords': ['데이터분석', '문제해결', '통계', 'Python', '리서치'],
      'reason': '데이터를 기반으로 논리적으로 문제를 파악하고 해결하는 능력이 뛰어납니다.',
      'lacking': ['비즈니스이해', '시각화']
    },
    {
      'jobTitle': '소프트웨어 개발자',
      'keywords': ['PROGRAMMING', '개발', '알고리즘', '협업'],
      'reason': '코드로 결과물을 만들어내는 프로그래밍 역량과 기술적 사고가 일치합니다.',
      'lacking': ['시스템아키텍처', '보안지식']
    },
    {
      'jobTitle': '마케터',
      'keywords': ['마케팅', '콘텐츠', '트렌드', '창의성', 'SNS'],
      'reason': '트렌드를 읽고 매력적인 콘텐츠로 사람들의 마음을 움직이는 역량이 충분합니다.',
      'lacking': ['퍼포먼스분석', '카피라이팅']
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final prefs = await SharedPreferences.getInstance();

    // 💡 핵심: 기존에 있던 false/true 하드코딩 대입 코드를 완전히 삭제하고 실제 값만 꺼내옵니다.
    _isSubscribed = prefs.getBool('isSubscribed') ?? false;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot = await FirebaseFirestore.instance
          .collection('activities')
          .where('userId', isEqualTo: user.uid)
          .get();

      Set<String> tags = {};
      for (var doc in snapshot.docs) {
        final docTags = doc['tags'] ?? [];
        for (var t in docTags) {
          tags.add(t.toString().toUpperCase()); // 대문자로 정규화하여 저장된 태그 가져오기
        }
      }
      _userTags = tags.toList();
    }

    setState(() {
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> _calculateRecommendations() {
    List<Map<String, dynamic>> results = [];

    for (var job in _jobMappings) {
      int matchCount = 0;
      List<String> keywords = job['keywords'];

      for (var tag in _userTags) {
        String upperTag = tag.toUpperCase();
        if (keywords.any((k) => upperTag.contains(k.toUpperCase()) || k.toUpperCase().contains(upperTag))) {
          matchCount++;
        }
      }

      int score = 40 + (matchCount * 15);
      if (score > 98) score = 98;

      if (_userTags.isEmpty) {
        score = 30 + (job['jobTitle'].toString().length * 2); // 💡 num타입 에러 방지용 수정한 코드 유지
      }

      results.add({
        ...job,
        'score': score,
      });
    }

    results.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    return results;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          'AI 직무 추천',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryIndigo))
          : Stack(
        children: [
          _buildRecommendationList(),
          if (!_isSubscribed) _buildLockedOverlay(),
        ],
      ),
    );
  }

  Widget _buildRecommendationList() {
    final recommendations = _calculateRecommendations();
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: recommendations.length,
            itemBuilder: (context, index) {
              final job = recommendations[index];
              return _buildJobCard(job);
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          width: double.infinity,
          color: Colors.grey.shade50,
          child: Text(
            '💡 더 많은 활동을 기록할수록 추천이 정확해져요',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        )
      ],
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(job['jobTitle'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: primaryIndigo.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Text('적합도 ${job['score']}%', style: TextStyle(color: primaryIndigo, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(job['reason'], style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.4)),
            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
            const Text('이런 역량을 더 채우면 완벽해요', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: (job['lacking'] as List<String>).map((skill) {
                return Chip(
                  label: Text(skill),
                  labelStyle: const TextStyle(fontSize: 12, color: Colors.deepOrange),
                  backgroundColor: Colors.deepOrange.withOpacity(0.08),
                  side: BorderSide.none,
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildLockedOverlay() {
    return Positioned.fill(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
          child: Container(
            color: Colors.white.withOpacity(0.4),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
                      child: Icon(Icons.lock_rounded, size: 48, color: primaryIndigo),
                    ),
                    const SizedBox(height: 24),
                    const Text('프리미엄 기능입니다', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 12),
                    const Text(
                      'AI가 당신의 활동 데이터를 심층 분석해\n가장 적합한 직무를 추천해 드려요',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, color: Colors.black87, height: 1.5, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 40),
                    const Text(
                      "💡 마이페이지 탭에서 무료 플랜을\n프리미엄으로 업그레이드할 수 있습니다.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.indigo, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}