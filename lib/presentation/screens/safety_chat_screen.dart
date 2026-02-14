import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import '../../providers/gemini_provider.dart';
import '../widgets/ai/chat_bubble.dart';

class SafetyChatScreen extends ConsumerStatefulWidget {
  const SafetyChatScreen({super.key});

  @override
  ConsumerState<SafetyChatScreen> createState() => _SafetyChatScreenState();
}

class _SafetyChatScreenState extends ConsumerState<SafetyChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    ref.read(chatProvider.notifier).sendMessage(text);

    // Scroll to bottom after message
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('\u{1F6E1}\uFE0F', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text(
              'SafePath AI',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () {
              ref.read(chatProvider.notifier).clearChat();
            },
            tooltip: 'Clear chat',
          ),
        ],
      ),
      body: Column(
        children: [
          // Suggestion chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _SuggestionChip(
                  text: 'Is Steeles Ave safe at night?',
                  onTap: () {
                    _textController.text = 'Is Steeles Ave safe at night?';
                    _sendMessage();
                  },
                ),
                _SuggestionChip(
                  text: 'Safest area in Markham?',
                  onTap: () {
                    _textController.text = 'What is the safest area in Markham?';
                    _sendMessage();
                  },
                ),
                _SuggestionChip(
                  text: 'Walking tips for nighttime',
                  onTap: () {
                    _textController.text =
                        'Give me walking safety tips for nighttime in York Region';
                    _sendMessage();
                  },
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.border),

          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: chatState.messages.length +
                  (chatState.isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < chatState.messages.length) {
                  final msg = chatState.messages[index];
                  return ChatBubble(
                    text: msg.text,
                    isUser: msg.isUser,
                    timestamp: msg.timestamp,
                  );
                }
                // Loading indicator
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(width: 40),
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.brand,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Thinking...',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Input bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(
                top: BorderSide(
                    color: AppColors.border.withValues(alpha: 0.3)),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Ask about any area...',
                        hintStyle: TextStyle(
                            color:
                                AppColors.textSecondary.withValues(alpha: 0.6)),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    onPressed:
                        chatState.isLoading ? null : _sendMessage,
                    icon: Icon(
                      Icons.send_rounded,
                      color: chatState.isLoading
                          ? AppColors.textSecondary
                          : AppColors.brand,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _SuggestionChip({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(
          text,
          style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
        ),
        backgroundColor: AppColors.card,
        side: BorderSide(color: AppColors.border.withValues(alpha: 0.3)),
        onPressed: onTap,
      ),
    );
  }
}
