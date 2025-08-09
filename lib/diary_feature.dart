import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'main.dart';
import 'ai_chat_feature.dart';
import 'gemini_service.dart';

// =================================================================================
// Diary List Screen
// =================================================================================
class DiaryScreen extends StatelessWidget {
  final String uid;

  const DiaryScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Diary"),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AddEditDiaryEntryScreen(uid: uid),
              ),
            ),
            label: const Text("Add New Entry"),
            icon: const Icon(Icons.add),
            heroTag: 'add_entry',
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<DiaryEntry>>(
              stream: firestoreService.getDiaryEntriesStream(uid),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const SizedBox.shrink();
                }
                return FloatingActionButton.extended(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DiaryChatScreen(
                        entries: snapshot.data!,
                      ),
                    ),
                  ),
                  label: const Text("Chat with Diary AI"),
                  icon: const Icon(Icons.chat_bubble_outline),
                  heroTag: 'chat_with_diary_ai',
                  backgroundColor: Theme.of(context).primaryColor,
                );
              }),
        ],
      ),
      body: StreamBuilder<List<DiaryEntry>>(
        stream: firestoreService.getDiaryEntriesStream(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          final entries = snapshot.data ?? [];

          if (entries.isEmpty) {
            return const _EmptyDiaryState();
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 150),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return _DiaryEntryCard(
                entry: entry,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        AddEditDiaryEntryScreen(uid: uid, entry: entry),
                  ),
                ),
                onDelete: () => _confirmDelete(context, uid, entry.id!),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, String uid, String entryId) async {
    final bool? shouldDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Entry?"),
        content: const Text(
            "Are you sure you want to permanently delete this diary entry?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Delete",
                  style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (shouldDelete == true) {
      await FirestoreService().deleteDiaryEntry(uid, entryId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Entry deleted successfully'),
            backgroundColor: Colors.green),
      );
    }
  }
}

// =================================================================================
// Add/Edit Diary Entry Screen
// =================================================================================
class AddEditDiaryEntryScreen extends StatefulWidget {
  final String uid;
  final DiaryEntry? entry;

  const AddEditDiaryEntryScreen({super.key, required this.uid, this.entry});

  @override
  _AddEditDiaryEntryScreenState createState() =>
      _AddEditDiaryEntryScreenState();
}

class _AddEditDiaryEntryScreenState extends State<AddEditDiaryEntryScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  bool get _isEditMode => widget.entry != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _titleController.text = widget.entry!.title;
      _contentController.text = widget.entry!.content;
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);

      final newEntry = DiaryEntry(
        id: widget.entry?.id,
        title: _titleController.text,
        content: _contentController.text,
        timestamp: Timestamp.now(),
      );

      try {
        if (_isEditMode) {
          await FirestoreService().updateDiaryEntry(widget.uid, newEntry);
        } else {
          await FirestoreService().addDiaryEntry(widget.uid, newEntry);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Diary entry ${_isEditMode ? 'updated' : 'saved'} successfully!'),
                backgroundColor: Colors.green),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Failed to submit: $e")));
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? "Edit Entry" : "New Diary Entry"),
        actions: [
          if (_isSubmitting)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child:
                  Center(child: CircularProgressIndicator(color: Colors.white)),
            )
          else
            IconButton(
              icon: const Icon(Icons.save_outlined),
              onPressed: _submitForm,
              tooltip: 'Save',
            )
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  hintText: 'Title of your entry',
                  border: InputBorder.none,
                ),
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
                validator: (v) => v!.isEmpty ? 'Title is required' : null,
              ),
            ),
            const Divider(color: Colors.white12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: TextFormField(
                  controller: _contentController,
                  decoration: const InputDecoration(
                    hintText:
                        'Write about your day, observations, and thoughts...',
                    border: InputBorder.none,
                  ),
                  style: Theme.of(context).textTheme.bodyLarge,
                  maxLines: null, // Allows for multiline input
                  keyboardType: TextInputType.multiline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =================================================================================
// Diary Chat Screen
// =================================================================================
class DiaryChatScreen extends StatefulWidget {
  final List<DiaryEntry> entries;
  const DiaryChatScreen({super.key, required this.entries});

  @override
  State<DiaryChatScreen> createState() => _DiaryChatScreenState();
}

class _DiaryChatScreenState extends State<DiaryChatScreen> {
  final _messageController = TextEditingController();
  final GeminiService _geminiService = GeminiService();
  final _historyService = const ChatHistoryService('diary_chat_history');
  final ImagePicker _picker = ImagePicker();

  List<ChatMessage> _chatHistory = [];
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadHistory();
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
      final response = await _geminiService.getDiaryChatResponse(
        userQuery: messageText,
        entries: widget.entries,
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
        title: const Text('Diary AI Assistant'),
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
                    child: Text("Ask me anything about your diary entries!"))
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
            IconButton.filled(
              style: IconButton.styleFrom(
                  backgroundColor: Colors.white, foregroundColor: Colors.black),
              icon: const Icon(Icons.add_photo_alternate_outlined),
              onPressed: _pickImage,
              tooltip: 'Attach Photo',
            ),
            const SizedBox(width: 4),
            IconButton.filled(
              style: IconButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor),
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
// Helper Widgets
// =================================================================================

class _EmptyDiaryState extends StatelessWidget {
  const _EmptyDiaryState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book,
                size: 80,
                color: Theme.of(context).primaryColor.withOpacity(0.5)),
            const SizedBox(height: 24),
            Text(
              "Your Diary is Empty",
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              "Tap 'Add New Entry' to start recording your thoughts, experiences, and memories.",
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiaryEntryCard extends StatelessWidget {
  final DiaryEntry entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _DiaryEntryCard(
      {required this.entry, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.title,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat.yMMMMd()
                              .add_jm()
                              .format(entry.timestamp.toDate()),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.redAccent),
                    onPressed: onDelete,
                    tooltip: 'Delete',
                  ),
                ],
              ),
              const Divider(height: 24, color: Colors.white12),
              Text(
                entry.content,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: Colors.grey.shade300),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}