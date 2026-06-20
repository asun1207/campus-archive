// TODO: 실제 배포 시 Claude/Gemini API 연동 예정
// 현재는 Firestore 데이터 기반 더미 응답으로 시연

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AiCounselingScreen extends StatefulWidget {
  const AiCounselingScreen({super.key});

  @override
  State<AiCounselingScreen> createState() => _AiCounselingScreenState();
}

class _AiCounselingScreenState extends State<AiCounselingScreen> {
  final Color primaryIndigo = const Color(0xFF4F46E5);
  bool _isAiThinking = false;

  final List<Map<String, String>> _messages = [
    {"sender": "ai", "text": "안녕하세요! 진로에 대해 어떤 고민이 있으신가요?"},
  ];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // 💡 핵심: 하드코딩을 제거하고, 호출될 때마다 SharedPreferences에서 실시간으로 상태를 읽어오는 Future 함수
  Future<bool> _getSubscriptionStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isSubscribed') ?? false;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSubmitted(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add({"sender": "user", "text": text});
      _isAiThinking = true;
    });
    _textController.clear();
    _scrollToBottom();

    await Future.delayed(const Duration(milliseconds: 1500));
    String aiResponse = await _generateDummyResponse(text);

    if (mounted) {
      setState(() {
        _isAiThinking = false;
        _messages.add({"sender": "ai", "text": aiResponse});
      });
      _scrollToBottom();
    }
  }

  Future<String> _generateDummyResponse(String input) async {
    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.displayName ?? "사용자";

    if (input == "어떤 직무가 맞을까요?") {
      if (user == null) return "로그인이 필요한 기능입니다.";
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('activities')
            .where('userId', isEqualTo: user.uid)
            .get();

        final docs = snapshot.docs;
        if (docs.isEmpty) {
          return "$userName님의 활동 데이터가 아직 부족해요. '활동 기록' 탭에서 데이터를 더 쌓아주시면 훨씬 정확한 직무 추천이 가능합니다!";
        }

        Map<String, int> tagCounts = {};
        for (var doc in docs) {
          final tags = doc['tags'] ?? [];
          for (var tag in tags) {
            tagCounts[tag.toString()] = (tagCounts[tag.toString()] ?? 0) + 1;
          }
        }

        if (tagCounts.isEmpty) {
          return "$userName님의 활동 기록은 확인되지만 '태그'가 없네요! 기록에 핵심 역량 태그를 추가해 주시면 어떤 점이 돋보이는지 분석해 드릴게요.";
        }

        var sortedTags = tagCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        String topTags = sortedTags.take(3).map((e) => "'${e.key}'").join(', ');

        return "지금까지 $userName님이 기록해주신 활동 데이터를 분석해 봤어요!\n\n주로 $topTags 관련 역량을 꾸준히 키워오셨네요. 이런 데이터 흐름을 볼 때, 이 역량들을 적극 활용할 수 있는 직무(예: 서비스 기획, 데이터 분석, 마케팅 등)가 적성에 아주 잘 맞으실 것 같아요.\n\n가장 흥미를 느꼈던 활동은 무엇이었나요?";
      } catch (e) {
        return "데이터를 분석하는 중 오류가 발생했어요. 잠시 후 다시 시도해 주세요.";
      }
    } else if (input == "대학원 갈까요?") {
      return "대학원 진학은 '연구하고 싶은 구체적인 주제'가 있는지, 그리고 학부 연구생이나 딥다이브 프로젝트 경험이 재미있었는지가 가장 중요해요.\n\n$userName님이 기존에 하셨던 활동 중 특히 아쉬움이 남아 더 깊게 파고들고 싶었던 분야가 있었나요?";
    } else if (input == "부족한 역량이 뭔가요?") {
      return "현재 기록된 데이터를 기반으로 볼 때 전공 지식과 교내 활동은 탄탄하지만, 상대적으로 외부 사람들과 부딪히며 협업하는 '대외 활동' 경험이 약간 부족해 보여요.\n\n다음 학기에는 타 학교 학생들과 교류할 수 있는 연합 동아리나 해커톤, 공모전에 도전해 보는 건 어떨까요?";
    } else if (input == "추가하면 좋을 활동은?") {
      return "희망하시는 직무 방향성과 관련된 실무 경험(인턴십, 산학협력 프로젝트)을 1~2개 정도만 더 추가하시면 완벽할 것 같아요! 혹은 부족한 실무 스킬을 채울 수 있는 4주짜리 단기 직무 부트캠프도 추천해 드립니다.";
    } else {
      return "좋은 질문이에요!\n\n'$input'에 대해 더 자세하고 깊이 있는 맞춤 상담을 위해서는 실제 AI 연동이 필요해요.\n\n(곧 업데이트될 실제 배포 버전에서는 Claude/Gemini API가 붙어서 더욱 전문적인 답변을 해드릴 예정입니다 🚀)";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'AI 진로 상담',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
      ),
      // 💡 핵심: FutureBuilder를 사용하여 탭이 빌드될 때마다 최신 실시간 SharedPreferences 값을 감지함
      body: FutureBuilder<bool>(
        future: _getSubscriptionStatus(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: primaryIndigo));
          }

          final isSubscribed = snapshot.data ?? false;

          return isSubscribed
              ? _buildChatScreen()      // 구독 중이면 채팅창
              : _buildLockedScreen();   // 미구독이면 잠금화면
        },
      ),
    );
  }

// ==========================================
  // 1. 미구독 상태 (블러 처리된 잠금 화면 UI)
  // ==========================================
  Widget _buildLockedScreen() {
    return Stack(
      children: [
        // 배경: 실제 채팅 화면의 '이미지' (캡처본처럼 보이게 함)
        // 💡 실제 채팅 기능을 빼고 UI 껍데기만 렌더링하여 배경으로 사용
        Opacity(
          opacity: 0.5, // 약간 어둡게 처리
          child: Column(
            children: [
              // 상단 예시 칩 영역 (클릭 불가)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _buildExampleChip("어떤 직무가 맞을까요?"), const SizedBox(width: 8),
                      _buildExampleChip("대학원 갈까요?"), const SizedBox(width: 8),
                      _buildExampleChip("부족한 역량이 뭔가요?"),
                    ],
                  ),
                ),
              ),
              // 가짜 메시지 말풍선들
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  physics: const NeverScrollableScrollPhysics(), // 스크롤 금지
                  children: [
                    _buildMessageBubble("안녕하세요! 진로에 대해 어떤 고민이 있으신가요?", false),
                    _buildMessageBubble("내 활동 데이터를 기반으로 직무를 추천해줘.", true),
                    _buildTypingIndicator(), // AI가 생각하는 척
                  ],
                ),
              ),
              // 하단 입력창 껍데기
              Container(
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
              ),
            ],
          ),
        ),

        // 그 위에 블러 처리 및 자물쇠 오버레이 덮기
        Positioned.fill(
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0), // 블러 강도
              child: Container(
                color: Colors.white.withOpacity(0.3), // 반투명 오버레이
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 자물쇠 아이콘 (직무 추천 화면과 통일)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                          ),
                          child: Icon(Icons.lock_rounded, size: 48, color: primaryIndigo),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          '프리미엄 기능입니다',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'AI가 당신의 활동 데이터를 심층 분석해\n진로를 맞춤 상담해드려요',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 15, color: Colors.black87, height: 1.5, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 40),
                        // 안내 문구 (직무 추천 화면과 통일)
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
        ),
      ],
    );
  }

  // --- 구독 상태 (채팅 UI) ---
  Widget _buildChatScreen() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildExampleChip("어떤 직무가 맞을까요?"),
                const SizedBox(width: 8),
                _buildExampleChip("대학원 갈까요?"),
                const SizedBox(width: 8),
                _buildExampleChip("부족한 역량이 뭔가요?"),
                const SizedBox(width: 8),
                _buildExampleChip("추가하면 좋을 활동은?"),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length + (_isAiThinking ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _messages.length && _isAiThinking) {
                return _buildTypingIndicator();
              }
              final message = _messages[index];
              final isUser = message["sender"] == "user";
              return _buildMessageBubble(message["text"]!, isUser);
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), offset: const Offset(0, -2), blurRadius: 8)],
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: 'AI에게 진로 고민을 물어보세요...',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onSubmitted: _handleSubmitted,
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 22,
                  backgroundColor: primaryIndigo,
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    onPressed: () => _handleSubmitted(_textController.text),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExampleChip(String text) {
    return ActionChip(
      label: Text(text),
      labelStyle: TextStyle(color: primaryIndigo, fontSize: 13, fontWeight: FontWeight.w500),
      backgroundColor: primaryIndigo.withOpacity(0.08),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onPressed: () => _handleSubmitted(text),
    );
  }

  Widget _buildMessageBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? primaryIndigo : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20).copyWith(
            bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(20),
            bottomLeft: isUser ? const Radius.circular(20) : const Radius.circular(0),
          ),
        ),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Text(text, style: TextStyle(color: isUser ? Colors.white : Colors.black87, fontSize: 15, height: 1.4)),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20).copyWith(bottomLeft: const Radius.circular(0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: primaryIndigo.withOpacity(0.5)),
            ),
            const SizedBox(width: 10),
            const Text('AI가 데이터를 분석 중입니다...', style: TextStyle(color: Colors.black54, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}