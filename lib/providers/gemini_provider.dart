import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'route_provider.dart';

/// Chat message for safety assistant
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  const ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

/// Chat state
class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;

  const ChatState({
    this.messages = const [],
    this.isLoading = false,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ChatNotifier extends Notifier<ChatState> {
  @override
  ChatState build() {
    // Add welcome message
    return ChatState(messages: [
      ChatMessage(
        text:
            "Hi! I'm your SafePath AI assistant. Ask me anything about walking safety in York Region. "
            'Try: "Is Steeles Ave safe at night?" or "What areas should I avoid?"',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    ]);
  }

  Future<void> sendMessage(String text) async {
    // Add user message
    final userMsg = ChatMessage(
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isLoading: true,
    );

    // Get AI response
    final gemini = ref.read(geminiServiceProvider);
    final response = await gemini.askSafetyQuestion(text);

    final aiMsg = ChatMessage(
      text: response,
      isUser: false,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, aiMsg],
      isLoading: false,
    );
  }

  void clearChat() {
    final gemini = ref.read(geminiServiceProvider);
    gemini.resetChat();
    state = const ChatState();
  }
}

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(
  ChatNotifier.new,
);
