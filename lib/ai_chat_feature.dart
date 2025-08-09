import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'main.dart'; // To access Plant, GeminiService, etc.
import 'gemini_service.dart';
// =================================================================================
// Chat Message Data Model
// =================================================================================
class ChatMessage {
  final String role;
  final String text;
  final String? base64Image;

  ChatMessage({required this.role, required this.text, this.base64Image});

  Map<String, dynamic> toJson() => {
        'role': role,
        'text': text,
        'base64Image': base64Image,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        role: json['role'],
        text: json['text'],
        base64Image: json['base64Image'],
      );
}

// =================================================================================
// Chat History Service (for Local Storage)
// =================================================================================
class ChatHistoryService {
  final String storageKey;
  const ChatHistoryService(this.storageKey);

  Future<void> saveChatHistory(List<ChatMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(messages.map((m) => m.toJson()).toList());
    await prefs.setString(storageKey, jsonString);
  }

  Future<List<ChatMessage>> loadChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(storageKey);
    if (jsonString == null) return [];
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((json) => ChatMessage.fromJson(json)).toList();
  }

  Future<void> clearChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
  }
}

// =================================================================================
// Main AI Chat Screen
// =================================================================================
class AiChatScreen extends StatefulWidget {
  final List<Plant> plants;
  final bool openWithImagePicker; // To handle the shortcut

  const AiChatScreen({
    super.key,
    required this.plants,
    this.openWithImagePicker = false,
  });

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _messageController = TextEditingController();
  final GeminiService _geminiService = GeminiService();
  final _historyService = const ChatHistoryService('global_chat_history');
  final ImagePicker _picker = ImagePicker();

  List<ChatMessage> _chatHistory = [];
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadHistory();
    if (widget.openWithImagePicker) {
      // Use a short delay to allow the screen to build first
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pickImage();
      });
    }
  }

  Future<void> _loadHistory() async {
    final history = await _historyService.loadChatHistory();
    setState(() => _chatHistory = history);
  }

  Future<void> _pickImage() async {
    final XFile? image =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) {
      final imageBytes = await image.readAsBytes();
      final base64Image = base64Encode(imageBytes);
      _sendMessage(image: base64Image);
    }
  }

  Future<void> _sendMessage({String? image}) async {
    final messageText = _messageController.text;
    if (messageText.isEmpty && image == null) return;

    final userMessage =
        ChatMessage(role: 'user', text: messageText, base64Image: image);
    _messageController.clear();

    setState(() {
      _chatHistory.add(userMessage);
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final response = await _geminiService.getChatResponse(
        userQuery: messageText,
        plants: widget.plants,
        base64Image: image,
      );
      final modelMessage = ChatMessage(role: 'model', text: response);
      setState(() => _chatHistory.add(modelMessage));
    } catch (e) {
      final errorMessage = ChatMessage(
          role: 'model',
          text: "Error: Could not connect to AI service. $e");
      setState(() => _chatHistory.add(errorMessage));
    } finally {
      setState(() => _isLoading = false);
      _historyService.saveChatHistory(_chatHistory);
      _scrollToBottom();
    }
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

  Future<void> _clearChat() async {
    final bool? shouldClear = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clear Chat History?"),
        content:
            const Text("This will permanently delete all messages in this chat."),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Clear",
                  style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (shouldClear == true) {
      await _historyService.clearChatHistory();
      setState(() => _chatHistory.clear());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Farm Advisor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: _clearChat,
            tooltip: 'Clear Chat History',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _chatHistory.isEmpty
                ? const Center(
                    child: Text("Ask me anything about your farm!"))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _chatHistory.length,
                    itemBuilder: (context, index) {
                      return ChatMessageWidget(message: _chatHistory[index]);
                    },
                  ),
          ),
          if (_isLoading)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: LinearProgressIndicator(
                  color: Theme.of(context).primaryColor),
            ),
          _buildInputArea(),
        ],
      ),
    );
  }



  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(color: Theme.of(context).cardTheme.color),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: 'Type a message or add a photo...',
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            // [FIXED] Changed button to white with a black icon for max contrast
            IconButton.filled(
              style: IconButton.styleFrom(
                  backgroundColor: Colors.white, foregroundColor: Colors.black),
              icon: const Icon(Icons.add_photo_alternate_outlined),
              onPressed: _pickImage,
              tooltip: 'Attach Photo',
            ),
             const SizedBox(width: 4),
            IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
              icon: const Icon(Icons.send),
              onPressed: () => _sendMessage(),
            )
          ],
        ),
      ),
    );
  }  

}

// =================================================================================
// Chat Message Widget
// =================================================================================
class ChatMessageWidget extends StatelessWidget {
  final ChatMessage message;
  const ChatMessageWidget({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser
              ? Theme.of(context).primaryColor
              : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: isUser ? const Radius.circular(20) : Radius.zero,
            bottomRight: isUser ? Radius.zero : const Radius.circular(20),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.base64Image != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  base64Decode(message.base64Image!),
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            if (message.text.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(
                    top: message.base64Image != null ? 10.0 : 0),
                child: MarkdownBody(
                  data: message.text,
                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                      .copyWith(
                          p: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: isUser ? Colors.black : Colors.white)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}