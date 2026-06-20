import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AiCounselingScreen extends StatefulWidget {
  const AiCounselingScreen({super.key});

  @override
  State<AiCounselingScreen> createState() => _AiCounselingScreenState();
}

class _AiCounselingScreenState extends State<AiCounselingScreen> {
  final Color primaryIndigo = const Color(0xFF4F46E5);
  bool _isSubscribed = false;
  bool _isLoading = true;

  // --- 더미 채팅 데이터 및 컨트롤러 ---
  final List<Map<String, String>> _messages = [
    {"sender": "ai", "text": "안녕하세요! 진로에 대해 어떤 고민이 있으신가요?"},
  ];
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkSubscriptionStatus();
  }

  // --- 구독 상태 확인 함수 ---
  Future<void> _checkSubscriptionStatus() async {
    final prefs = await SharedPreferences.getInstance();

    // 💡 잠금 화면을 먼저 확인하기 위해 강제로 false 하드코딩
    // (테스트 후 나중에 이 줄을 지우면 실제 저장된 값을 바라보게 됩니다)
    await prefs.setBool('isSubscribed', true);

    setState(() {
      _isSubscribed = prefs.getBool('isSubscribed') ?? false;
      _isLoading = false;
    });
  }

  // --- 메시지 전송 처리 함수 ---
  void _handleSubmitted(String text) {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add({"sender": "user", "text": text});
      // 임시 AI 더미 답변 (다음 단계에서 Claude API로 교체 예정)
      _messages.add({"sender": "ai", "text": "AI 답변 기능은 다음 단계에서 연동될 예정입니다!"});
    });
    _textController.clear();
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
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryIndigo))
          : _isSubscribed
          ? _buildChatScreen()      // 구독 O: 채팅 UI
          : _buildLockedScreen(),   // 구독 X: 잠금 UI
    );
  }

  // ==========================================
  // 1. 미구독 상태 (잠금 화면 UI)
  // ==========================================
  Widget _buildLockedScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 24),
            const Text(
              '프리미엄 기능입니다',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'AI가 당신의 활동 데이터를 분석해\n진로를 맞춤 상담해드려요',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                  height: 1.5
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: 결제 연동 시 실제 동작할 함수
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('결제 연동은 다음 단계에서 진행됩니다.')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryIndigo,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  '월 4,900원으로 시작하기',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 2. 구독 상태 (카카오톡 스타일 채팅 UI)
  // ==========================================
  Widget _buildChatScreen() {
    return Column(
      children: [
        // 상단 예시 질문 칩 영역 (가로 스크롤)
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

        // 채팅 메시지 리스트 영역
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final message = _messages[index];
              final isUser = message["sender"] == "user";
              return _buildMessageBubble(message["text"]!, isUser);
            },
          ),
        ),

        // 하단 텍스트 입력창
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                offset: const Offset(0, -2),
                blurRadius: 8,
              )
            ],
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
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onSubmitted: _handleSubmitted, // 엔터 키 누를 때 전송
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

  // UI 컴포넌트: 예시 질문 칩
  Widget _buildExampleChip(String text) {
    return ActionChip(
      label: Text(text),
      labelStyle: TextStyle(color: primaryIndigo, fontSize: 13, fontWeight: FontWeight.w500),
      backgroundColor: primaryIndigo.withOpacity(0.08),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onPressed: () => _handleSubmitted(text), // 칩 누르면 바로 채팅방에 전송
    );
  }

  // UI 컴포넌트: 카카오톡 스타일 말풍선
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
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75, // 화면의 75%까지만 차지
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUser ? Colors.white : Colors.black87,
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}