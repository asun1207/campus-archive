import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final Color primaryIndigo = const Color(0xFF4F46E5);
  final User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '역량 분석',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _buildAnalysisStream(),
    );
  }

  // --- Firestore 데이터 실시간 패칭 ---
  Widget _buildAnalysisStream() {
    if (currentUser == null) {
      return const Center(child: Text('로그인이 필요합니다.'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('activities')
          .where('userId', isEqualTo: currentUser!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: primaryIndigo));
        }

        if (snapshot.hasError) {
          return Center(child: Text('데이터를 불러오는 중 오류가 발생했습니다.'));
        }

        final docs = snapshot.data?.docs ?? [];

        // 1. 데이터가 5개 미만일 때 빈 데이터 상태 표시
        if (docs.length < 5) {
          return _buildInsufficientDataState(docs.length);
        }

        // 2. 차트에 사용할 데이터 집계
        int totalActivities = docs.length;
        int subjectCount = 0;
        int schoolCount = 0;
        int outsideCount = 0;
        Map<String, int> tagCounts = {};

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;

          // 카테고리 집계
          final category = data['category'] ?? '';
          if (category == '수강 과목') subjectCount++;
          if (category == '교내 활동') schoolCount++;
          if (category == '대외 활동') outsideCount++;

          // 태그 집계
          final List<dynamic> tags = data['tags'] ?? [];
          for (var tag in tags) {
            final tagStr = tag.toString();
            tagCounts[tagStr] = (tagCounts[tagStr] ?? 0) + 1;
          }
        }

        // 태그를 빈도수 기준으로 내림차순 정렬
        var sortedTags = tagCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 요약 카드 섹션
              _buildSummaryCards(totalActivities, subjectCount, tagCounts.length),
              const SizedBox(height: 40),

              // 태그별 활동 분포 (도넛 차트)
              const Text(
                '태그별 활동 분포',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              _buildTagPieChart(sortedTags),
              const SizedBox(height: 48),

              // 카테고리별 활동 비율 (막대 차트)
              const Text(
                '카테고리별 활동 비율',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              _buildCategoryBarChart(subjectCount, schoolCount, outsideCount),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  // --- UI 컴포넌트: 데이터 부족 상태 ---
  Widget _buildInsufficientDataState(int currentCount) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pie_chart_outline_rounded, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 20),
          Text(
            '분석을 위한 데이터가 부족해요',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[800]),
          ),
          const SizedBox(height: 12),
          Text(
            '기록을 더 쌓으면 분석이 정확해져요!\n(현재 $currentCount개 / 최소 5개 필요)',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey[600], height: 1.5),
          ),
        ],
      ),
    );
  }

  // --- UI 컴포넌트: 상단 요약 카드 3개 ---
  Widget _buildSummaryCards(int total, int subjects, int tags) {
    return Row(
      children: [
        _buildSingleSummaryCard('전체 활동', '$total개'),
        const SizedBox(width: 12),
        _buildSingleSummaryCard('수강 과목', '$subjects개'),
        const SizedBox(width: 12),
        _buildSingleSummaryCard('태그 종류', '$tags개'),
      ],
    );
  }

  Widget _buildSingleSummaryCard(String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: primaryIndigo.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primaryIndigo.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(fontSize: 18, color: primaryIndigo, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI 컴포넌트: 태그 분포 도넛 차트 (PieChart) ---
  Widget _buildTagPieChart(List<MapEntry<String, int>> sortedTags) {
    // 차트에 너무 많은 태그가 나오면 지저분하므로 상위 5개까지만 보여주고 나머지는 기타로 묶기
    final topTags = sortedTags.take(5).toList();
    final otherTagsCount = sortedTags.skip(5).fold(0, (sum, item) => sum + item.value);

    if (otherTagsCount > 0) {
      topTags.add(MapEntry('기타', otherTagsCount));
    }

    // 인디고 계열 그라데이션 색상 리스트
    final colors = [
      primaryIndigo,
      primaryIndigo.withOpacity(0.8),
      primaryIndigo.withOpacity(0.6),
      primaryIndigo.withOpacity(0.4),
      primaryIndigo.withOpacity(0.25),
      Colors.grey.shade300,
    ];

    int totalTags = topTags.fold(0, (sum, item) => sum + item.value);

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 50, // 도넛 차트를 위한 중앙 빈 공간
              sections: topTags.asMap().entries.map((entry) {
                int idx = entry.key;
                var tag = entry.value;
                double percentage = (tag.value / totalTags) * 100;

                return PieChartSectionData(
                  color: colors[idx % colors.length],
                  value: tag.value.toDouble(),
                  title: '${percentage.toStringAsFixed(1)}%',
                  radius: 40,
                  titleStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // 차트 하단 범례 (Legend)
        Wrap(
          spacing: 16,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: topTags.asMap().entries.map((entry) {
            int idx = entry.key;
            var tag = entry.value;
            double percentage = (tag.value / totalTags) * 100;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: colors[idx % colors.length],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${tag.key} (${percentage.toStringAsFixed(1)}%)',
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  // --- UI 컴포넌트: 카테고리 비율 막대 차트 (BarChart) ---
  Widget _buildCategoryBarChart(int subjectCount, int schoolCount, int outsideCount) {
    // 가장 높은 값을 찾아서 y축 최대값 설정
    double maxY = [subjectCount, schoolCount, outsideCount].reduce((a, b) => a > b ? a : b).toDouble();
    // 그래프 상단 여유 공간
    maxY = maxY == 0 ? 5 : maxY + (maxY * 0.2);

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          barTouchData: BarTouchData(enabled: false), // 터치 효과 비활성화 (깔끔한 UI용)
          titlesData: FlTitlesData(
            show: true,
            // X축 (하단) 라벨
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  const style = TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 13);
                  String text;
                  switch (value.toInt()) {
                    case 0: text = '수강 과목'; break;
                    case 1: text = '교내 활동'; break;
                    case 2: text = '대외 활동'; break;
                    default: text = ''; break;
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(text, style: style),
                  );
                },
              ),
            ),
            // 왼쪽, 오른쪽, 위쪽 라벨 숨기기
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: false), // 배경 격자 선 숨기기
          borderData: FlBorderData(show: false), // 차트 테두리 숨기기
          barGroups: [
            _buildBarGroup(0, subjectCount.toDouble(), primaryIndigo),
            _buildBarGroup(1, schoolCount.toDouble(), primaryIndigo.withOpacity(0.7)),
            _buildBarGroup(2, outsideCount.toDouble(), primaryIndigo.withOpacity(0.4)),
          ],
        ),
      ),
    );
  }

  // 막대 차트 개별 Bar 생성 함수
  BarChartGroupData _buildBarGroup(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 32,
          borderRadius: BorderRadius.circular(6),
          // 막대 위에 숫자 표시
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: y,
            color: Colors.transparent,
          ),
        ),
      ],
      showingTooltipIndicators: [0], // 항상 값 표시 툴팁 띄우기
    );
  }
}