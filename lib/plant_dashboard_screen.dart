import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'main.dart';
import 'app_config.dart';
import 'gemini_service.dart';
import 'ai_chat_feature.dart';

class PlantDashboardScreen extends StatefulWidget {
  final Plant plant;
  const PlantDashboardScreen({super.key, required this.plant});
  @override
  State<PlantDashboardScreen> createState() => _PlantDashboardScreenState();
}

class _PlantDashboardScreenState extends State<PlantDashboardScreen>
    with WidgetsBindingObserver {
  final GeminiService _geminiService = GeminiService();
  final WeatherService _weatherService = WeatherService();
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  String? _healthStatus;
  bool _isCheckingHealth = false;

  String? _weatherAdvisories;
  bool _isFetchingWeather = false;
  Map<String, dynamic>? _weatherData;

  String? _governmentSchemes;
  bool _isFetchingSchemes = false;

  String? _marketTrends;
  bool _isFetchingTrends = false;

  Map<String, dynamic>? _latestSensorData;
  bool _isLoadingSensorData = true;

  bool _isWeatherExpanded = false;
  bool _isSchemesExpanded = false;
  bool _isTrendsExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLatestSensorData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadLatestSensorData();
  }

  Future<void> _loadLatestSensorData() async {
    setState(() => _isLoadingSensorData = true);
    try {
      final data =
          await _firestoreService.getLatestSensorReading(widget.plant.id);
      if (mounted) setState(() => _latestSensorData = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Could not load sensor data: $e"),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoadingSensorData = false);
    }
  }

  Future<void> _checkPlantHealth() async {
    setState(() => _isCheckingHealth = true);
    final status = await _geminiService.getPlantHealthStatus(
        widget.plant, _latestSensorData);
    if (mounted) {
      setState(() {
        _healthStatus = status;
        _isCheckingHealth = false;
      });
    }
  }

  Future<void> _fetchWeatherAdvisory() async {
    setState(() {
      _isFetchingWeather = true;
      _weatherAdvisories = null;
      _weatherData = null;
    });
    try {
      final weather = await _weatherService.getCurrentWeather(
          widget.plant.latitude, widget.plant.longitude);
      if (mounted) setState(() => _weatherData = weather);
      final advisories = await _geminiService.getWeatherBasedSuggestions(
          widget.plant, weather);
      if (mounted) setState(() => _weatherAdvisories = advisories);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Error fetching weather advisory: ${e.toString()}"),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isFetchingWeather = false);
    }
  }

  Future<void> _fetchGovernmentSchemes() async {
    setState(() {
      _isFetchingSchemes = true;
      _governmentSchemes = null;
    });
    try {
      final schemes = await _geminiService.getGovernmentSchemes(widget.plant);
      if (mounted) setState(() => _governmentSchemes = schemes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Error fetching schemes: ${e.toString()}"),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isFetchingSchemes = false);
    }
  }

  Future<void> _fetchMarketTrends() async {
    setState(() {
      _isFetchingTrends = true;
      _marketTrends = null;
    });
    try {
      final trends = await _geminiService.getMarketTrends(widget.plant);
      if (mounted) setState(() => _marketTrends = trends);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Error fetching market trends: ${e.toString()}"),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isFetchingTrends = false);
    }
  }

  Future<void> _launchSensorWebApp() async {
    final user = _authService.getCurrentUser();
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You must be logged in.")));
      return;
    }
    if (AppConstants.flaskServerUrl.contains('YOUR_COMPUTER_IP_ADDRESS')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              "Please set your computer's IP address in AppConstants."),
          backgroundColor: Colors.red));
      return;
    }
    final token = await user.getIdToken();
    final url = Uri.parse(
        '${AppConstants.flaskServerUrl}/sensor/${widget.plant.id}?token=$token');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Could not open sensor page. Error: $e"),
          backgroundColor: Colors.red));
    }
  }

  Future<void> _saveSnapshotToDiary() async {
    final user = _authService.getCurrentUser();
    if (user == null) return;

    if (_latestSensorData == null && _weatherData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("No sensor or weather data available to save."),
            backgroundColor: Colors.orange),
      );
      return;
    }

    final now = DateTime.now();
    final title =
        "Field Report for ${widget.plant.name} - ${DateFormat.yMMMd().format(now)}";

    final StringBuffer content = StringBuffer();
    content.writeln("This is an automated snapshot of your field conditions.");

    if (_latestSensorData != null) {
      content.writeln("\n**Sensor Readings:**");
      content.writeln(
          "- Temperature: ${_latestSensorData!['temp']?.toStringAsFixed(1) ?? 'N/A'}°C");
      content.writeln(
          "- Humidity: ${_latestSensorData!['humidity']?.toStringAsFixed(1) ?? 'N/A'}%");
      content.writeln(
          "- Soil Moisture: ${_latestSensorData!['moisture']?.toStringAsFixed(1) ?? 'N/A'}%");
      content.writeln(
          "- Light Level: ${_latestSensorData!['light']?.toStringAsFixed(1) ?? 'N/A'}%");
    }

    if (_weatherData != null) {
      content.writeln("\n**Weather Conditions:**");
      content.writeln(
          "- Condition: ${_weatherData!['weather'][0]['description']}");
      content.writeln("- Temperature: ${_weatherData!['main']['temp']}°C");
      content.writeln("- Feels Like: ${_weatherData!['main']['feels_like']}°C");
    }

    final newEntry = DiaryEntry(
      title: title,
      content: content.toString(),
      timestamp: Timestamp.now(),
    );

    try {
      await _firestoreService.addDiaryEntry(user.uid, newEntry);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Snapshot saved to your diary!"),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Failed to save to diary: $e"),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.plant.name)),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => AICompanionScreen(
                    plant: widget.plant,
                    latestSensorData: _latestSensorData))),
            tooltip: 'AI Companion',
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text("AI Companion"),
          ),
          const SizedBox(height: 16),
          FloatingActionButton.extended(
            onPressed: _saveSnapshotToDiary,
            tooltip: 'Save Snapshot to Diary',
            icon: const Icon(Icons.save_alt_outlined),
            label: const Text("Save Snapshot"),
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.black,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLiveSensorDataSection(),
            const SizedBox(height: 24),
            _buildHealthStatusCard(),
            const SizedBox(height: 24),
            _buildWeatherAdvisoryCard(),
            const SizedBox(height: 24),
            _buildGovernmentSchemesCard(),
            const SizedBox(height: 24),
            _buildMarketTrendsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthStatusCard() => Card(
        color: const Color(0xFF312536),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              const Icon(Icons.favorite_border,
                  color: Color(0xFFE57373), size: 40),
              const SizedBox(width: 16),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text("AI Health Status",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white70)),
                    const SizedBox(height: 4),
                    _isCheckingHealth
                        ? const LinearProgressIndicator()
                        : Text(
                            _healthStatus ?? "Tap refresh to check.",
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(color: Colors.white),
                          )
                  ])),
              IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _checkPlantHealth)
            ],
          ),
        ),
      );

  Widget _buildWeatherAdvisoryCard() {
    const cardColor = Color(0xFFC7814C);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () =>
                setState(() => _isWeatherExpanded = !_isWeatherExpanded),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  const Icon(Icons.wb_cloudy_outlined,
                      color: cardColor, size: 40),
                  const SizedBox(width: 16),
                  const Expanded(
                      child: Text("Weather Advisory",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18))),
                  if (!_isFetchingWeather && _weatherAdvisories == null)
                    ElevatedButton(
                      onPressed: _fetchWeatherAdvisory,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: cardColor,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20))),
                      child: const Text("GET"),
                    )
                  else
                    Icon(_isWeatherExpanded
                        ? Icons.expand_less
                        : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (_isFetchingWeather)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _weatherAdvisories != null
                ? Container(
                    color: cardColor.withOpacity(0.1),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_weatherData != null) ...[
                          Card(
                            elevation: 0,
                            color: cardColor.withOpacity(0.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  const Icon(Icons.thermostat_auto_outlined,
                                      color: Colors.redAccent),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      "${_weatherData!['main']['temp']}°C, ${_weatherData!['weather'][0]['description']}",
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Divider(height: 24, color: Colors.white12),
                        ],
                        MarkdownBody(
                            data: _weatherAdvisories!,
                            styleSheet: MarkdownStyleSheet.fromTheme(
                                Theme.of(context)).copyWith(
                                p: Theme.of(context).textTheme.bodyLarge)),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
            crossFadeState: _isWeatherExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _buildGovernmentSchemesCard() {
    const cardColor = Color(0xFF4CA49E);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () =>
                setState(() => _isSchemesExpanded = !_isSchemesExpanded),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_outlined,
                      color: cardColor, size: 40),
                  const SizedBox(width: 16),
                  const Expanded(
                      child: Text("Government Schemes",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18))),
                  if (!_isFetchingSchemes && _governmentSchemes == null)
                    ElevatedButton(
                      onPressed: _fetchGovernmentSchemes,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: cardColor,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20))),
                      child: const Text("FIND"),
                    )
                  else
                    Icon(_isSchemesExpanded
                        ? Icons.expand_less
                        : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (_isFetchingSchemes)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _governmentSchemes != null
                ? Container(
                    width: double.infinity,
                    color: cardColor.withOpacity(0.1),
                    padding: const EdgeInsets.all(16.0),
                    child: MarkdownBody(
                        data: _governmentSchemes!,
                        styleSheet: MarkdownStyleSheet.fromTheme(
                            Theme.of(context)).copyWith(
                            p: Theme.of(context).textTheme.bodyLarge)),
                  )
                : const SizedBox.shrink(),
            crossFadeState: _isSchemesExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketTrendsCard() {
    const cardColor = Color(0xFF4C89C7);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isTrendsExpanded = !_isTrendsExpanded),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  const Icon(Icons.trending_up_outlined,
                      color: cardColor, size: 40),
                  const SizedBox(width: 16),
                  const Expanded(
                      child: Text("Market Trends",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18))),
                  if (!_isFetchingTrends && _marketTrends == null)
                    ElevatedButton(
                      onPressed: _fetchMarketTrends,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: cardColor,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20))),
                      child: const Text("ANALYZE"),
                    )
                  else
                    Icon(_isTrendsExpanded
                        ? Icons.expand_less
                        : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (_isFetchingTrends)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _marketTrends != null
                ? Container(
                    width: double.infinity,
                    color: cardColor.withOpacity(0.1),
                    padding: const EdgeInsets.all(16.0),
                    child: MarkdownBody(
                        data: _marketTrends!,
                        styleSheet: MarkdownStyleSheet.fromTheme(
                            Theme.of(context)).copyWith(
                            p: Theme.of(context).textTheme.bodyLarge)),
                  )
                : const SizedBox.shrink(),
            crossFadeState: _isTrendsExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveSensorDataSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Live Sensor Data",
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          _isLoadingSensorData
              ? const Center(child: CircularProgressIndicator())
              : _latestSensorData == null
                  ? _buildGetSensorDataButton()
                  : _buildSensorDataGrid()
        ],
      );

  Widget _buildGetSensorDataButton() => Center(
          child: ElevatedButton.icon(
              onPressed: _launchSensorWebApp,
              icon: const Icon(Icons.sensors),
              label: const Text("Get Live Sensor Data")));

  Widget _buildSensorDataGrid() => Column(children: [
        GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.1,
            children: [
              _buildSensorTile(
                  Icons.thermostat,
                  "Temperature",
                  "${_latestSensorData!['temp']?.toStringAsFixed(1) ?? 'N/A'}°C",
                  const Color(0xFFF48FB1)), // Pink
              _buildSensorTile(
                  Icons.water_drop_outlined,
                  "Humidity",
                  "${_latestSensorData!['humidity']?.toStringAsFixed(1) ?? 'N/A'}%",
                  const Color(0xFF81D4FA)), // Light Blue
              _buildSensorTile(
                  Icons.water,
                  "Soil Moisture",
                  "${_latestSensorData!['moisture']?.toStringAsFixed(1) ?? 'N/A'}%",
                  const Color(0xFFCE93D8)), // Purple
              _buildSensorTile(
                  Icons.wb_sunny_outlined,
                  "Light Level",
                  "${_latestSensorData!['light']?.toStringAsFixed(1) ?? 'N/A'}%",
                  const Color(0xFFFFD54F)) // Yellow
            ]),
        const SizedBox(height: 24),
        _buildGetSensorDataButton()
      ]);

  Widget _buildSensorTile(
          IconData icon, String label, String value, Color color) =>
      Card(
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.3), color.withOpacity(0.1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: color.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 40, color: color),
                const SizedBox(height: 12),
                Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 4),
                Text(value,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(color: color, fontWeight: FontWeight.w900))
              ],
            ),
          ),
        ),
      );
}

// =================================================================================
// AI Companion Screen (Chat)
// =================================================================================
class AICompanionScreen extends StatefulWidget {
  final Plant plant;
  final Map<String, dynamic>? latestSensorData;
  const AICompanionScreen(
      {super.key, required this.plant, this.latestSensorData});

  @override
  State<AICompanionScreen> createState() => _AICompanionScreenState();
}

class _AICompanionScreenState extends State<AICompanionScreen> {
  final _messageController = TextEditingController();
  final GeminiService _geminiService = GeminiService();
  late final ChatHistoryService _historyService;
  final ImagePicker _picker = ImagePicker();

  List<ChatMessage> _chatHistory = [];
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _historyService = ChatHistoryService('plant_chat_${widget.plant.id}');
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await _historyService.loadChatHistory();
    setState(() => _chatHistory = history);
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
        plants: [widget.plant],
        latestSensorData: widget.latestSensorData,
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

  Future<void> _clearChat() async {
    final bool? shouldClear = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clear Chat History?"),
        content: const Text(
            "This will permanently delete all messages in this chat."),
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
        title: Text('AI Companion for ${widget.plant.name}'),
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
                ? Center(
                    child: Text("Ask anything about ${widget.plant.name}"))
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
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(),
            ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: 'Ask a question...',
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            // [FIXED] Changed button to white with a black icon for max contrast
            IconButton.filled(
              style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black),
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