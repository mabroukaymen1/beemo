import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:teemo/widgets/colors.dart'; // Ensure this path is correct and AppColors is defined

class CommandCenterChatScreen extends StatefulWidget {
  final String userId;
  final String companyId;
  final String baseUrl;

  const CommandCenterChatScreen({
    Key? key,
    this.userId = "9fa3c3bb-35fd-402f-917a-d35abd974e70",
    this.companyId = "ffff43a9-d8c3-4e62-a3ec-88628af73a45",
    this.baseUrl = "https://projet-pfe-seven.vercel.app",
  }) : super(key: key);

  @override
  State<CommandCenterChatScreen> createState() =>
      _CommandCenterChatScreenState();
}

class _CommandCenterChatScreenState extends State<CommandCenterChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  String? _sessionId;
  bool _isLoading = false;
  bool _isTyping = false;
  bool _connectionError = false;

  // Move controller initialization to declaration to avoid LateInitializationError
  late TextEditingController _userIdController = TextEditingController();
  late TextEditingController _companyIdController = TextEditingController();
  late TextEditingController _baseUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _userIdController.text = widget.userId;
    _companyIdController.text = widget.companyId;
    _baseUrlController.text = widget.baseUrl;
    _initFirebaseAndSession();
  }

  Future<void> _initFirebaseAndSession() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    await _initializeSession();
  }

  CollectionReference<Map<String, dynamic>> _messagesCollection(
      String sessionId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('companies')
        .doc(widget.companyId)
        .collection('sessions')
        .doc(sessionId)
        .collection('messages');
  }

  Future<void> _loadMessagesFromFirebase(String sessionId) async {
    final snapshot =
        await _messagesCollection(sessionId).orderBy('timestamp').get();
    if (!mounted) return;
    setState(() {
      _messages.clear();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        _messages.add(ChatMessage(
          content: data['content'] ?? '',
          isFromAI: data['isFromAI'] ?? false,
          timestamp: (data['timestamp'] as Timestamp).toDate(),
          hasToolCall: data['hasToolCall'] ?? false,
          isError: data['isError'] ?? false,
        ));
      }
    });
    _scrollToBottom();
  }

  Future<void> _saveMessageToFirebase(
      String sessionId, ChatMessage message) async {
    await _messagesCollection(sessionId).add({
      'content': message.content,
      'isFromAI': message.isFromAI,
      'timestamp': message.timestamp,
      'hasToolCall': message.hasToolCall,
      'isError': message.isError,
    });
  }

  String get _apiBase =>
      "${_baseUrlController.text}/api/v1/${_userIdController.text}/companies/${_companyIdController.text}/command-center";

  // Add this method to fetch AI responses from command_history
  Future<List<ChatMessage>> _fetchAIResponsesFromCommandHistory() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('command_history')
          .where('user_id', isEqualTo: widget.userId)
          .orderBy('timestamp', descending: false)
          .limit(10)
          .get();

      List<ChatMessage> aiMessages = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['response'] != null &&
            data['response'].toString().trim().isNotEmpty) {
          aiMessages.add(ChatMessage(
            content: data['response'],
            isFromAI: true,
            timestamp:
                (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
            hasToolCall: false,
            isError: false,
          ));
        }
      }
      return aiMessages;
    } catch (e) {
      // Ignore errors, just return empty
      return [];
    }
  }

  // Fetch all command/response pairs from command_history and show in chat
  Future<List<ChatMessage>> _fetchCommandHistoryPairs() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('command_history')
          // Removed user_id filter to fetch all command history
          .orderBy('timestamp', descending: false)
          .get();

      List<ChatMessage> history = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        // Add user command if present
        if (data['command'] != null &&
            data['command'].toString().trim().isNotEmpty) {
          history.add(ChatMessage(
            content: data['command'],
            isFromAI: false,
            timestamp:
                (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
            hasToolCall: false,
            isError: false,
          ));
        }
        // Add AI response if present (support both 'response' and 'ai_response')
        final aiResp = data['ai_response'] ?? data['response'];
        if (aiResp != null && aiResp.toString().trim().isNotEmpty) {
          history.add(ChatMessage(
            content: aiResp,
            isFromAI: true,
            timestamp:
                (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
            hasToolCall: false,
            isError: false,
          ));
        }
      }
      return history;
    } catch (e) {
      print("Firestore fetch error: $e");
      return [];
    }
  }

  Future<void> _initializeSession() async {
    setState(() {
      _isLoading = true;
      _connectionError = false;
      _messages.clear();
    });

    print("Initializing session: $_apiBase/sessions/new");
    try {
      final response = await http.post(
        Uri.parse("$_apiBase/sessions/new"),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({"name": "Flutter Chat Session", "mode": "chat"}),
      );
      print("Session init response: ${response.statusCode} ${response.body}");

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['data'] != null && data['data']['session_id'] != null) {
          final sessionId = data['data']['session_id'];
          setState(() {
            _sessionId = sessionId;
          });
          await _loadMessagesFromFirebase(sessionId);

          // --- Fetch and show all command/response pairs from command_history ---
          if (_messages.isEmpty) {
            final history = await _fetchCommandHistoryPairs();
            if (history.isNotEmpty) {
              setState(() {
                _messages.addAll(history);
              });
            }
          }
          // --- End fetch ---

          // Show intro message only if still empty
          if (_messages.isEmpty) {
            final introMsg = ChatMessage(
              content:
                  "Hello! I'm your PFE Platform assistant. I can help you interact with the API using natural language commands. Ask me anything about databases, companies, projects, groups, users, or files. Type 'help' to see what I can do.",
              isFromAI: true,
              timestamp: DateTime.now(),
            );
            setState(() {
              _messages.add(introMsg);
            });
            await _saveMessageToFirebase(sessionId, introMsg);
          }
          setState(() => _connectionError = false);
        } else {
          _showError("Invalid session data received.");
          setState(() => _connectionError = true);
        }
      } else {
        _showError("Failed to initialize session: ${response.statusCode}");
        setState(() => _connectionError = true);
      }
    } catch (e) {
      print("Session init error: $e");
      if (!mounted) return;
      _showError("Failed to initialize session: $e");
      setState(() => _connectionError = true);
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty || _sessionId == null || _isLoading || _isTyping)
      return;

    final userMsg = ChatMessage(
      content: message,
      isFromAI: false,
      timestamp: DateTime.now(),
    );
    setState(() {
      _messages.add(userMsg);
      _isTyping = true;
    });
    await _saveMessageToFirebase(_sessionId!, userMsg);

    _messageController.clear();
    _scrollToBottom();

    print("Sending message: $message");
    try {
      final response = await http.post(
        Uri.parse("$_apiBase/sessions/$_sessionId"),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({"user_prompt": message}),
      );
      print("Send message response: ${response.statusCode} ${response.body}");
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final aiResponse = data['response'] ?? "No response received";
        final aiMsg = ChatMessage(
          content: aiResponse,
          isFromAI: true,
          timestamp: DateTime.now(),
          hasToolCall: _detectToolCall(aiResponse),
        );
        setState(() {
          _messages.add(aiMsg);
        });
        await _saveMessageToFirebase(_sessionId!, aiMsg);
      } else {
        _showError("Failed to send message: ${response.statusCode}");
      }
    } catch (e) {
      print("Send message error: $e");
      if (!mounted) return;
      _showError("Error: $e");
    } finally {
      if (!mounted) return;
      setState(() => _isTyping = false);
      _scrollToBottom();
    }
  }

  bool _detectToolCall(String response) {
    return response.contains('```tool_use');
  }

  Future<void> _acceptToolCall() async {
    if (_sessionId == null) return;
    setState(() => _isTyping = true);
    try {
      final response = await http.post(
        Uri.parse("$_apiBase/sessions/$_sessionId"),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({"accept_tool_call": true}),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final aiResponse = data['response'] ?? "Tool executed successfully";
        final aiMsg = ChatMessage(
          content: aiResponse,
          isFromAI: true,
          timestamp: DateTime.now(),
        );
        setState(() => _messages.add(aiMsg));
        await _saveMessageToFirebase(_sessionId!, aiMsg);
      } else {
        _showError("Failed to accept tool call: ${response.statusCode}");
      }
    } catch (e) {
      if (!mounted) return;
      _showError("Error accepting tool call: $e");
    } finally {
      if (!mounted) return;
      setState(() => _isTyping = false);
      _scrollToBottom();
    }
  }

  Future<void> _rejectToolCall() async {
    if (_sessionId == null) return;
    setState(() => _isTyping = true);
    try {
      final response = await http.post(
        Uri.parse("$_apiBase/sessions/$_sessionId"),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({"reject_tool_call": true}),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final aiResponse = data['response'] ?? "Tool execution declined";
        final aiMsg = ChatMessage(
          content: aiResponse,
          isFromAI: true,
          timestamp: DateTime.now(),
        );
        setState(() => _messages.add(aiMsg));
        await _saveMessageToFirebase(_sessionId!, aiMsg);
      } else {
        _showError("Failed to reject tool call: ${response.statusCode}");
      }
    } catch (e) {
      if (!mounted) return;
      _showError("Error rejecting tool call: $e");
    } finally {
      if (!mounted) return;
      setState(() => _isTyping = false);
      _scrollToBottom();
    }
  }

  void _showError(String message) {
    final errMsg = ChatMessage(
      content: "❌ $message",
      isFromAI: true,
      timestamp: DateTime.now(),
      isError: true,
    );
    if (!mounted) return;
    setState(() {
      _messages.add(errMsg);
    });
    if (_sessionId != null) {
      _saveMessageToFirebase(_sessionId!, errMsg);
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients &&
          _scrollController.position.hasContentDimensions) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _connectionError
                    ? Colors.redAccent
                    : (_isLoading ? Colors.orangeAccent : AppColors.secondary),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'PFE PLATFORM',
              style: GoogleFonts.poppins(
                textStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '...',
              style: GoogleFonts.poppins(
                  textStyle: TextStyle(color: Colors.grey[400], fontSize: 16)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: AppColors.secondary),
            tooltip: "Edit Configuration",
            onPressed: _showEditConfigDialog,
          ),
          if (_connectionError)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.redAccent),
              onPressed: _initializeSession,
              tooltip: "Retry Connection",
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: Icon(Icons.help_outline, color: Colors.grey[400]),
              onPressed: _showHelpDialog,
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: SizedBox(
            height: 24,
            child: Stack(
              children: [
                Center(
                  child: Container(
                    width: 100,
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.secondary, AppColors.primary],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _initializeSession,
                    icon: Icon(Icons.refresh, color: AppColors.primary),
                    label: Text(
                      'Update Configuration',
                      style: GoogleFonts.poppins(
                          textStyle: TextStyle(color: AppColors.primary)),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cardDark.withOpacity(0.5),
                      elevation: 0,
                      side: BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _showEditConfigDialog,
                  icon: Icon(Icons.edit, color: AppColors.secondary),
                  label: Text(
                    'Edit',
                    style: GoogleFonts.poppins(
                        textStyle: TextStyle(color: AppColors.secondary)),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.cardDark.withOpacity(0.5),
                    elevation: 0,
                    side: BorderSide(color: AppColors.secondary),
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? Center(
                    child:
                        CircularProgressIndicator(color: AppColors.secondary),
                  )
                : _messages.isEmpty && !_isTyping
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Text(
                            _connectionError
                                ? "Connection failed. Please retry configuration."
                                : "No messages yet. Start a conversation or use a command template below!",
                            style: GoogleFonts.poppins(
                                color: Colors.grey[400], fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: _messages.length + (_isTyping ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _messages.length) {
                            return _buildTypingIndicator();
                          }
                          return _buildMessageBubble(_messages[index]);
                        },
                      ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
                color: AppColors.cardDark,
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: AppColors.cardBorder.withOpacity(0.5))),
            child: Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent, // Removes default divider
                unselectedWidgetColor: Colors.grey[400],
              ),
              child: ExpansionTile(
                tilePadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                iconColor: Colors.grey[400],
                collapsedIconColor: Colors.grey[400],
                title: Row(
                  children: [
                    Icon(Icons.auto_awesome_mosaic_outlined,
                        color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'Command Templates',
                      style: GoogleFonts.poppins(
                          textStyle: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
                children: [
                  _buildCommandTemplate('List Databases', 'List all databases'),
                  _buildCommandTemplate('Create Project',
                      'Create a new project for mobile app development named "MobileApp"'),
                  _buildCommandTemplate(
                      'List Projects', 'Show all projects in this company'),
                  _buildCommandTemplate(
                      'Help', 'Show available commands and tools'),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(
                16, 16, 16, 20), // Added bottom padding
            decoration: BoxDecoration(
              color: AppColors.background,
              border: Border(top: BorderSide(color: AppColors.cardBorder)),
            ),
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.end, // Align items to bottom
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.cardDark,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                          color: AppColors.cardBorder.withOpacity(0.7)),
                    ),
                    child: TextField(
                      controller: _messageController,
                      style: GoogleFonts.poppins(
                          textStyle: const TextStyle(color: Colors.white)),
                      enabled: !_isLoading && !_isTyping && !_connectionError,
                      maxLines: null, // Allows multiline input
                      keyboardType: TextInputType.multiline,
                      decoration: InputDecoration(
                        hintText: _connectionError
                            ? 'Connection error...'
                            : 'Type a message or command...',
                        hintStyle: GoogleFonts.poppins(
                            textStyle: TextStyle(color: Colors.grey[500])),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                      ),
                      onSubmitted: (text) {
                        if (!_isLoading && !_isTyping && !_connectionError) {
                          _sendMessage(text);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Material(
                  // Wrap IconButton in Material for ink splash effect
                  color: AppColors.secondary,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: (!_isLoading && !_isTyping && !_connectionError)
                        ? () => _sendMessage(_messageController.text)
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Icon(Icons.send,
                          color: AppColors.background,
                          size: 24), // Dark icon on light bg
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditConfigDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.cardDark,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.settings, color: AppColors.secondary),
              const SizedBox(width: 8),
              Text("Edit Configuration",
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _userIdController,
                  style: GoogleFonts.poppins(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "User ID",
                    labelStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                    filled: true,
                    fillColor: AppColors.cardDark,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _companyIdController,
                  style: GoogleFonts.poppins(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Company ID",
                    labelStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                    filled: true,
                    fillColor: AppColors.cardDark,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _baseUrlController,
                  style: GoogleFonts.poppins(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Platform URL",
                    labelStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                    filled: true,
                    fillColor: AppColors.cardDark,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel",
                  style: GoogleFonts.poppins(
                      color: Colors.grey[400], fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                setState(() {
                  // Controllers already updated
                });
                Navigator.pop(context);
                _initializeSession();
              },
              child: Text("Save",
                  style: GoogleFonts.poppins(
                      color: AppColors.background,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    bool isUser = !message.isFromAI;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              backgroundColor: AppColors.secondary,
              radius: 18,
              child:
                  Icon(Icons.smart_toy, color: AppColors.background, size: 20),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser ? AppColors.primary : AppColors.cardDark,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                    border: Border.all(
                      color: message.isError
                          ? Colors.redAccent
                          : Colors.transparent, // No border unless error
                    ),
                  ),
                  child: Text(
                    message.content,
                    style: GoogleFonts.poppins(
                      textStyle: TextStyle(
                        color:
                            message.isError ? Colors.redAccent : Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                if (message.hasToolCall && !message.isError) ...[
                  // Only show for non-error tool calls
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: isUser
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
                    children: [
                      ElevatedButton.icon(
                        icon: Icon(Icons.check_circle_outline,
                            size: 18, color: AppColors.background),
                        onPressed: _acceptToolCall,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        label: Text('Accept',
                            style: GoogleFonts.poppins(
                                textStyle: TextStyle(
                                    color: AppColors.background,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13))),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: Icon(Icons.cancel_outlined,
                            size: 18, color: Colors.white),
                        onPressed: _rejectToolCall,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent.withOpacity(0.8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        label: Text('Reject',
                            style: GoogleFonts.poppins(
                                textStyle: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13))),
                      ),
                    ],
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.only(top: 5, left: 4, right: 4),
                  child: Text(
                    _formatTime(message.timestamp),
                    style: GoogleFonts.poppins(
                      textStyle: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 10),
            CircleAvatar(
              backgroundColor: AppColors.primary,
              radius: 18,
              child: Icon(Icons.person_outline, color: Colors.white, size: 20),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AppColors.secondary,
            radius: 18,
            child: Icon(Icons.smart_toy, color: AppColors.background, size: 20),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4), // Different for AI
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('AI is typing',
                    style: GoogleFonts.poppins(
                        textStyle: TextStyle(color: Colors.grey[400]))),
                const SizedBox(width: 8),
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: AppColors.secondary,
                    strokeWidth: 2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommandTemplate(String title, String command) {
    return ListTile(
      title: Text(title,
          style: GoogleFonts.poppins(
              textStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14))),
      subtitle: Text(command,
          style: GoogleFonts.poppins(
              textStyle: TextStyle(color: Colors.grey[500], fontSize: 12))),
      onTap: () {
        _messageController.text = command;
        // Optionally auto-send: _sendMessage(command);
        // Removed ExpansionTileController logic to avoid context error
        // If you want to close the ExpansionTile, manage its state with a bool in the parent widget.
      },
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      return "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";
    } else if (today.difference(messageDate).inDays == 1) {
      return "Yesterday ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";
    }
    return "${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year.toString().substring(2)} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.help_outline, color: AppColors.secondary, size: 24),
            const SizedBox(width: 10),
            Text("Chat Assistant Help",
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            "I can help you interact with the PFE Platform API using natural language.\n\n"
            "Examples:\n"
            "- 'List all my databases'\n"
            "- 'Create a new project called MyWebApp for web development'\n"
            "- 'Show users in the marketing group'\n"
            "- 'What files are in the project MyMobileApp?'\n\n"
            "You can also use the command templates below the chat list for quick actions. "
            "If I suggest an action (a 'tool call'), you can choose to 'Accept' or 'Reject' it.",
            style: GoogleFonts.poppins(color: Colors.grey[300], fontSize: 14),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Close",
                style: GoogleFonts.poppins(
                    color: AppColors.secondary, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _userIdController.dispose();
    _companyIdController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }
}

class ChatMessage {
  final String content;
  final bool isFromAI;
  final DateTime timestamp;
  final bool hasToolCall;
  final bool isError;

  ChatMessage({
    required this.content,
    required this.isFromAI,
    required this.timestamp,
    this.hasToolCall = false,
    this.isError = false,
  });
}
