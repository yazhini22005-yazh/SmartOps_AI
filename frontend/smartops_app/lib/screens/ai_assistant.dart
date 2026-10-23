import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

import '../theme/app_theme.dart';

class AIAssistant extends StatefulWidget {
  const AIAssistant({super.key});

  @override
  State<AIAssistant> createState() => _AIAssistantState();
}

class _AIAssistantState extends State<AIAssistant> {
  static const String baseUrl = 'http://127.0.0.1:8001';

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _isLoading = false;
  bool _speechAvailable = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _autoSpeak = true;

  String _voiceStatus = 'Voice assistant ready';

  final List<Map<String, String>> _messages = [
    {
      'type': 'ai',
      'message':
          'Vanakkam! Welcome to SmartOps AI Assistant. 😊\n\n'
          'Orders, workers, inventory pathi English or Thanglish-la kelunga. '
          'Backend data use panni answer panren.',
    },
  ];

  final List<String> _quickQuestions = [
    'Pending orders evlo irukku?',
    'Stock kammiya irukkura products enna?',
    'Ippo ethana workers active-ah irukaanga?',
    'Ethana orders complete aachu?',
  ];

  @override
  void initState() {
    super.initState();
    _initializeVoice();
  }

  // =========================================================
  // VOICE INITIALIZATION
  // =========================================================

  Future<void> _initializeVoice() async {
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;

          setState(() {
            _isListening = status == 'listening';

            if (status == 'listening') {
              _voiceStatus = 'Listening... pesunga';
            } else if (status == 'notListening') {
              _voiceStatus = 'Voice assistant ready';
            }
          });
        },
        onError: (error) {
          if (!mounted) return;

          setState(() {
            _isListening = false;
            _voiceStatus = 'Voice error: ${error.errorMsg}';
          });
        },
      );

      // The browser chooses a voice matching the language set before each chunk.
      // Wait for each speech chunk to finish before switching language.
      await _tts.setLanguage("en-IN");
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      await _tts.awaitSpeakCompletion(true);

      _tts.setStartHandler(() {
        if (!mounted) return;
        setState(() => _isSpeaking = true);
      });

      _tts.setCompletionHandler(() {
        if (!mounted) return;
        setState(() => _isSpeaking = false);
      });

      _tts.setCancelHandler(() {
        if (!mounted) return;
        setState(() => _isSpeaking = false);
      });

      if (!mounted) return;

      setState(() {
        _speechAvailable = available;
        _voiceStatus = available
            ? 'Voice assistant ready'
            : 'Speech recognition unavailable';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _speechAvailable = false;
        _voiceStatus = 'Voice initialization failed';
      });
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // =========================================================
  // START / STOP VOICE INPUT
  // =========================================================

  Future<void> _startListening() async {
    if (_isLoading) return;

    if (!_speechAvailable) {
      await _initializeVoice();

      if (!_speechAvailable) {
        _showMessage(
          'Speech recognition available illa. Browser microphone '
          'permission and speech recognition support check pannunga.',
        );
        return;
      }
    }

    await _tts.stop();

    if (!mounted) return;

    setState(() {
      _isSpeaking = false;
      _voiceStatus = 'Listening... pesunga';
    });

    try {
      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;

          setState(() {
            _controller.text = result.recognizedWords;
            _controller.selection = TextSelection.fromPosition(
              TextPosition(offset: _controller.text.length),
            );
          });

          if (result.finalResult) {
            final recognizedText = result.recognizedWords.trim();

            if (recognizedText.isNotEmpty) {
              _speech.stop();
              _sendMessage(recognizedText);
            }
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 4),
          partialResults: true,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _voiceStatus = 'Microphone start panna mudiyala';
        _isListening = false;
      });
    }
  }

  Future<void> _stopListening() async {
    await _speech.stop();

    if (!mounted) return;

    setState(() {
      _isListening = false;
      _voiceStatus = 'Voice assistant ready';
    });
  }

  // =========================================================
  // VOICE OUTPUT
  // =========================================================
     // =========================================================
  // MIXED TAMIL + ENGLISH VOICE OUTPUT
  // =========================================================

  /// Converts common Thanglish words to Tamil script for Tamil TTS.
  /// English/technical words remain in English.
  ///
  /// This is an offline, rule-based transliteration helper, not a
  /// full transliteration engine. Add words to this map when needed.
  String _convertThanglishWord(String word) {
    final lower = word.toLowerCase();

    const words = <String, String>{
      'vanakkam': 'வணக்கம்',
      'unga': 'உங்க',
      'ungaloda': 'உங்களோட',
      'ungalukku': 'உங்களுக்கு',
      'ungal': 'உங்கள்',
      'neenga': 'நீங்க',
      'naan': 'நான்',
      'naama': 'நாம',
      'namma': 'நம்ம',
      'enna': 'என்ன',
      'ethana': 'எத்தனை',
      'evlo': 'எவ்வளவு',
      'eppadi': 'எப்படி',
      'epdi': 'எப்படி',
      'irukku': 'இருக்கு',
      'irukkura': 'இருக்குற',
      'irukkaanga': 'இருக்காங்க',
      'irukkanga': 'இருக்காங்க',
      'irukkum': 'இருக்கும்',
      'illa': 'இல்ல',
      'illai': 'இல்லை',
      'aachu': 'ஆச்சு',
      'aagirukku': 'ஆகியிருக்கு',
      'aagirukanga': 'ஆகியிருக்காங்க',
      'mudinjiduchu': 'முடிஞ்சிடுச்சு',
      'mudinjirukku': 'முடிஞ்சிருக்கு',
      'mudiyala': 'முடியல',
      'kammiya': 'கம்மியா',
      'adhigama': 'அதிகமா',
      'pathi': 'பற்றி',
      'kelunga': 'கேளுங்க',
      'sollunga': 'சொல்லுங்க',
      'sollu': 'சொல்லு',
      'pannu': 'பண்ணு',
      'pannunga': 'பண்ணுங்க',
      'pannudhu': 'பண்ணுது',
      'pannuren': 'பண்ணுறேன்',
      'panren': 'பண்றேன்',
      'pannirukken': 'பண்ணிருக்கேன்',
      'panni': 'பண்ணி',
      'seiyunga': 'செய்யுங்க',
      'seiravanga': 'செய்றவங்க',
      'irundha': 'இருந்தா',
      'irundhu': 'இருந்து',
      'thevai': 'தேவை',
      'thevaiyaana': 'தேவையான',
      'poruththu': 'பொறுத்து',
      'calculate': 'calculate',
      'minimum': 'minimum',
      'current': 'current',
      'stock': 'stock',
      'inventory': 'inventory',
      'product': 'product',
      'products': 'products',
      'order': 'order',
      'orders': 'orders',
      'worker': 'worker',
      'workers': 'workers',
      'active': 'active',
      'pending': 'pending',
      'complete': 'complete',
      'completed': 'completed',
      'backend': 'backend',
      'database': 'database',
      'dashboard': 'dashboard',
      'report': 'report',
      'smartops': 'SmartOps',
      'units': 'units',
      'unit': 'unit',
      'status': 'status',
      'suggestion': 'suggestion',
      'welcome': 'welcome',
      'please': 'please',
      'check': 'check',
      'data': 'data',
      'use': 'use',
      'answer': 'answer',
      'actual': 'actual',
      'sales': 'sales',
      'demand': 'demand',
      'level': 'level',
      'reach': 'reach',
      'stockout': 'stockout',
    };

    final mapped = words[lower];
    if (mapped != null) return mapped;

    // Handle common Thanglish suffixes such as "inventory-la",
    // "stock-ku", and "active-ah". Keep the English root in English.
    final suffixes = <String, String>{
      '-la': ' ல',
      '-ku': ' கு',
      '-ah': ' ஆ',
      '-oda': ' ஓட',
      '-um': ' உம்',
      '-ai': ' ஐ',
    };

    for (final entry in suffixes.entries) {
      if (lower.endsWith(entry.key) &&
          lower.length > entry.key.length) {
        final root = word.substring(0, word.length - entry.key.length);
        return '$root${entry.value}';
      }
    }

    return word;
  }

  /// Turns the answer into sequential English/Tamil speech chunks.
  /// Tamil-script chunks use Microsoft Valluvar (ta-IN) when available;
  /// English chunks use an Indian English voice (en-IN) when available.
  List<Map<String, String>> _makeSpeechChunks(String text) {
    final chunks = <Map<String, String>>[];
    final pieces = text.split(RegExp(r'(\s+)'));

    for (final piece in pieces) {
      if (piece.isEmpty) continue;

      // Keep whitespace with the previous chunk so pauses and formatting
      // remain natural. Punctuation-only pieces are handled similarly.
      if (RegExp(r'^\s+$').hasMatch(piece)) {
        if (chunks.isNotEmpty) {
          chunks.last['text'] = '${chunks.last['text']}$piece';
        }
        continue;
      }

      final match = RegExp(
        r'^([^A-Za-z0-9]*)([A-Za-z0-9_-]+)([^A-Za-z0-9]*)$',
      ).firstMatch(piece);

      final converted = match == null
          ? piece
          : '${match.group(1) ?? ''}'
              '${_convertThanglishWord(match.group(2) ?? '')}'
              '${match.group(3) ?? ''}';

      final hasTamil = RegExp(r'[\u0B80-\u0BFF]').hasMatch(converted);
      final language = hasTamil ? 'ta-IN' : 'en-IN';

      // Attach punctuation-only text to the previous speech chunk.
      if (RegExp(r'^[^A-Za-z0-9\u0B80-\u0BFF]+$').hasMatch(converted)) {
        if (chunks.isNotEmpty) {
          chunks.last['text'] = '${chunks.last['text']}$converted';
        }
        continue;
      }

      if (chunks.isNotEmpty && chunks.last['language'] == language) {
        chunks.last['text'] = '${chunks.last['text']}$converted';
      } else {
        chunks.add({'language': language, 'text': converted});
      }
    }

    return chunks
        .where((chunk) => (chunk['text'] ?? '').trim().isNotEmpty)
        .toList();
  }

  Future<void> _speakAnswer(String text, {bool force = false}) async {
    if ((!_autoSpeak && !force) || text.trim().isEmpty) return;

    try {
      await _tts.stop();
      final chunks = _makeSpeechChunks(text);

      for (final chunk in chunks) {
        if (!mounted) return;

        final language = chunk['language'] ?? 'en-IN';
        final speechText = chunk['text'] ?? '';
        if (speechText.trim().isEmpty) continue;

        await _tts.setLanguage(language);
        await _tts.speak(speechText);
      }

      if (!mounted) return;
      setState(() {
        _isSpeaking = false;
        _voiceStatus = 'Voice assistant ready';
      });
    } catch (e) {
      debugPrint('Voice playback error: $e');
      if (!mounted) return;

      setState(() {
        _voiceStatus = 'Voice playback unavailable';
        _isSpeaking = false;
      });
    }
  }


  Future<void> _toggleAutoSpeak() async {
    setState(() {
      _autoSpeak = !_autoSpeak;
    });

    if (!_autoSpeak) {
      await _tts.stop();
      if (!mounted) return;

      setState(() {
        _isSpeaking = false;
        _voiceStatus = 'Voice replies muted';
      });
    } else {
      if (!mounted) return;
      setState(() {
        _voiceStatus = 'Voice replies enabled';
      });
    }
  }

  // =========================================================
  // SEND MESSAGE
  // =========================================================

  Future<void> _sendMessage(String message) async {
    final question = message.trim();

    if (question.isEmpty || _isLoading) return;

    if (_isListening) {
      await _speech.stop();
    }

    await _tts.stop();

    _controller.clear();

    if (!mounted) return;

    setState(() {
      _isListening = false;

      _messages.add({
        'type': 'user',
        'message': question,
      });

      _isLoading = true;
      _voiceStatus = 'SmartOps data check pannudhu...';
    });

    _scrollToBottom();

    String answer;

    try {
      answer = await _generateDatabaseResponse(question);
    } catch (e) {
      answer =
          'SmartOps backend connect aagala. Please check:\n\n'
          '1. FastAPI backend running-la irukka?\n'
          '2. Backend URL correct-ah irukka?\n'
          '3. API endpoint available-ah irukka?\n\n'
          'Technical details: $e';
    }

    if (!mounted) return;

    setState(() {
      _messages.add({
        'type': 'ai',
        'message': answer,
      });

      _isLoading = false;
      _voiceStatus = 'Response ready';
    });

    _scrollToBottom();

    // AI answer automatically voice-la play aagum.
    await _speakAnswer(answer);
  }

  // =========================================================
  // FETCH BACKEND JSON
  // =========================================================

  Future<dynamic> _getJson(String path) async {
    final uri = Uri.parse('$baseUrl$path');

    final response = await http
        .get(
          uri,
          headers: const {
            'Accept': 'application/json',
          },
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw Exception(
        'API $path returned HTTP ${response.statusCode}',
      );
    }

    return jsonDecode(response.body);
  }

  // =========================================================
  // SAFE DATA HELPERS
  // =========================================================

  Map<String, dynamic> _toMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    return {};
  }

  List<dynamic> _toList(dynamic data) {
    if (data is List) return data;

    if (data is Map) {
      final map = _toMap(data);

      for (final key in [
        'items',
        'products',
        'workers',
        'orders',
        'results',
        'data',
      ]) {
        if (map[key] is List) {
          return map[key] as List<dynamic>;
        }
      }
    }

    return [];
  }

  int _readInt(
    Map<String, dynamic> data,
    List<String> possibleKeys,
  ) {
    for (final key in possibleKeys) {
      final value = data[key];

      if (value is num) return value.toInt();

      if (value != null) {
        final parsed = num.tryParse(value.toString());

        if (parsed != null) return parsed.toInt();
      }
    }

    return 0;
  }

  String _readString(
    Map<String, dynamic> data,
    List<String> possibleKeys, {
    String fallback = 'Unknown',
  }) {
    for (final key in possibleKeys) {
      final value = data[key];

      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }

    return fallback;
  }

  // =========================================================
  // QUESTION NORMALIZATION
  // =========================================================

  String _normalize(String question) {
    return question
        .toLowerCase()
        .replaceAll(RegExp(r'[?!.,;:]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _containsAny(String text, List<String> phrases) {
    return phrases.any((phrase) => text.contains(phrase));
  }

  // =========================================================
  // DATABASE-BASED QUESTION ANSWERS
  // =========================================================

  Future<String> _generateDatabaseResponse(String question) async {
    final q = _normalize(question);

    // LOW STOCK / INVENTORY

    final asksStock = _containsAny(q, [
      'stock',
      'inventory',
      'product',
      'products',
      'restock',
      'reorder',
      'porul',
      'saraku',
      'iruppu',
      'stock kammi',
      'stock theer',
      'stock mudinj',
    ]);

    if (asksStock) {
      final raw = await _getJson('/products/low-stock');
      final products = _toList(raw);

      if (products.isEmpty) {
        return 'Ippo low-stock products API-la edhuvum return aagala. '
            'Products API response-ai verify pannunga.';
      }

      final buffer = StringBuffer();

      buffer.writeln('SmartOps Inventory Report.');
      buffer.writeln();

      for (final item in products) {
        final product = _toMap(item);

        final name = _readString(
          product,
          ['name', 'product_name', 'productName'],
          fallback: 'Unknown product',
        );

        final stock = _readInt(
          product,
          ['current_stock', 'currentStock', 'stock', 'quantity'],
        );

        final minimum = _readInt(
          product,
          [
            'min_stock_level',
            'minimum_stock',
            'min_stock',
            'minStock',
          ],
        );

        final deficit = minimum - stock;

        buffer.writeln('Product: $name');
        buffer.writeln('Current stock: $stock units');
        buffer.writeln('Minimum stock: $minimum units');

        if (deficit > 0) {
          buffer.writeln('Status: Low stock.');
          buffer.writeln('Suggestion: $deficit units restock pannunga.');
        } else {
          buffer.writeln('Status: Minimum stock level meet aagudhu.');
        }

        buffer.writeln();
      }

      buffer.writeln(
        'Minimum stock level reach panna thevaiyaana units '
        'calculate pannirukken. Sales demand-ai poruththu '
        'actual order quantity maaralaam.',
      );

      return buffer.toString();
    }

    // LOCATION / WORKLOAD

    final asksLocation = _containsAny(q, [
      'location',
      'workload',
      'delivery count',
      'deliveries',
      'which area',
      'highest workload',
      'entha area',
      'entha location',
      'entha idam',
      'area-wise',
    ]);

    if (asksLocation) {
      return 'Location-wise workload calculate panna ovvoru '
          'location-oda delivery count and pending orders data thevai. '
          'Adhukkana API-ai next build pannalaam.';
    }

    // PENDING ORDERS

    if (_containsAny(q, [
      'pending',
      'innum mudiyala',
      'mudiyatha order',
      'balance order',
      'complete aagala',
      'waiting order',
      'waiting orders',
      'meedhi order',
      'meethi order',
    ])) {
      final summary = _toMap(
        await _getJson('/dashboard/summary'),
      );

      final count = _readInt(
        summary,
        ['pending_orders', 'pendingOrders'],
      );

      return 'Ippo SmartOps database-padi $count pending orders irukku.';
    }

    // COMPLETED ORDERS

    if (_containsAny(q, [
      'completed',
      'complete aachu',
      'complete aagirukku',
      'mudinjiduchu',
      'mudinjirukku',
      'mudichachu',
      'finish aachu',
      'finished orders',
    ])) {
      final summary = _toMap(
        await _getJson('/dashboard/summary'),
      );

      final count = _readInt(
        summary,
        ['completed_orders', 'completedOrders'],
      );

      return 'SmartOps dashboard-padi $count orders complete aagirukku.';
    }

    // ACTIVE WORKERS

    if (_containsAny(q, [
      'active worker',
      'active workers',
      'how many worker',
      'how many workers',
      'worker count',
      'staff count',
      'ethana worker',
      'evlo worker',
      'workers active',
      'worker active',
      'ethana staff',
      'evlo staff',
      'delivery staff',
      'delivery person',
      'delivery persons',
      'velai seiravanga',
    ])) {
      final summary = _toMap(
        await _getJson('/dashboard/summary'),
      );

      final count = _readInt(
        summary,
        ['active_workers', 'activeWorkers'],
      );

      return 'Ippo SmartOps dashboard-padi $count active workers irukkaanga.';
    }

    // WORKER DETAILS

    if (_containsAny(q, [
      'worker',
      'workers',
      'staff',
      'show workers',
      'list workers',
      'worker details',
      'worker location',
      'staff location',
    ])) {
      final workers = _toList(await _getJson('/workers'));

      if (workers.isEmpty) {
        return 'Backend-la worker records kidaikkala.';
      }

      final buffer = StringBuffer();

      buffer.writeln('SmartOps Worker Details.');
      buffer.writeln();

      for (final item in workers) {
        final worker = _toMap(item);

        final name = _readString(
          worker,
          ['name', 'worker_name', 'workerName'],
          fallback: 'Unknown worker',
        );

        final location = _readString(
          worker,
          ['location', 'current_location', 'currentLocation'],
          fallback: 'Location unavailable',
        );

        final status = _readString(
          worker,
          ['status', 'worker_status', 'workerStatus'],
          fallback: 'Status unavailable',
        );

        buffer.writeln('Name: $name');
        buffer.writeln('Location: $location');
        buffer.writeln('Status: $status');
        buffer.writeln();
      }

      return buffer.toString();
    }

    // TOTAL ORDERS

    if (_containsAny(q, [
      'total order',
      'total orders',
      'order count',
      'orders count',
      'ethana order',
      'evlo order',
      'overall orders',
      'all orders',
    ])) {
      final summary = _toMap(
        await _getJson('/dashboard/summary'),
      );

      final count = _readInt(
        summary,
        ['total_orders', 'totalOrders'],
      );

      return 'SmartOps-la total-ah $count orders irukku.';
    }

    return 'Ungaloda question-ai innum understand panna mudiyala.\n\n'
        'Try pannunga:\n'
        'Pending orders evlo?\n'
        'Stock kammiya irukkura products enna?\n'
        'Ethana workers active-ah irukaanga?\n'
        'Ethana orders complete aachu?';
  }

  // =========================================================
  // SCROLL TO BOTTOM
  // =========================================================

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // =========================================================
  // UI
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: AppTheme.text,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    AppTheme.primary,
                    AppTheme.secondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: AppTheme.text,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SmartOps AI',
                  style: TextStyle(
                    color: AppTheme.text,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Voice Manager Assistant',
                  style: TextStyle(
                    color: Colors.black45,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _autoSpeak ? 'Mute voice replies' : 'Enable voice replies',
            onPressed: _toggleAutoSpeak,
            icon: Icon(
              _autoSpeak ? Icons.volume_up : Icons.volume_off,
              color: AppTheme.secondary,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // AI HEADER

          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  AppTheme.primary,
                  AppTheme.secondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.record_voice_over,
                  color: AppTheme.accent,
                  size: 32,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SmartOps Voice Assistant',
                        style: TextStyle(
                          color: AppTheme.text,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _voiceStatus,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isListening)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.text,
                    ),
                  ),
              ],
            ),
          ),

          // QUICK QUESTIONS

          SizedBox(
            height: 48,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: _quickQuestions.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: ActionChip(
                    label: Text(_quickQuestions[index]),
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: AppTheme.secondary.withValues(alpha: 0.3),
                    ),
                    labelStyle: const TextStyle(
                      color: AppTheme.text,
                      fontSize: 12,
                    ),
                    onPressed: _isLoading
                        ? null
                        : () => _sendMessage(_quickQuestions[index]),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 10),

          // CHAT MESSAGES

          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 10,
              ),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isLoading && index == _messages.length) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.secondary,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'SmartOps data check pannudhu...',
                            style: TextStyle(
                              color: AppTheme.text,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final message = _messages[index];
                final isUser = message['type'] == 'user';
                final text = message['message'] ?? '';

                return Align(
                  alignment: isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 650),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: isUser ? AppTheme.accent : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isUser ? 18 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 18),
                      ),
                      border: Border.all(
                        color: isUser
                            ? AppTheme.accent
                            : AppTheme.secondary.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(
                          text,
                          style: TextStyle(
                            color: isUser ? Colors.white : AppTheme.text,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                        if (!isUser)
                          Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                              tooltip: 'Read answer aloud',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _speakAnswer(text, force: true),
                              icon: Icon(
                                _isSpeaking
                                    ? Icons.volume_up_rounded
                                    : Icons.volume_up_outlined,
                                color: AppTheme.secondary,
                                size: 20,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // MESSAGE INPUT + MICROPHONE

          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
              decoration: const BoxDecoration(
                color: Colors.white,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !_isLoading,
                      onSubmitted: _sendMessage,
                      decoration: InputDecoration(
                        hintText: _isListening
                            ? 'Pesunga...'
                            : 'Ask in English or Thanglish...',
                        hintStyle: const TextStyle(
                          color: Colors.black38,
                          fontSize: 13,
                        ),
                        filled: true,
                        fillColor: AppTheme.background,
                        prefixIcon: const Icon(
                          Icons.chat_bubble_outline,
                          color: AppTheme.secondary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // MICROPHONE BUTTON

                  Container(
                    width: 48,
                    height: 50,
                    decoration: BoxDecoration(
                      color: _isListening
                          ? Colors.red
                          : AppTheme.secondary,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: IconButton(
                      tooltip: _isListening
                          ? 'Stop listening'
                          : 'Start voice input',
                      onPressed: _isLoading
                          ? null
                          : () {
                              if (_isListening) {
                                _stopListening();
                              } else {
                                _startListening();
                              }
                            },
                      icon: Icon(
                        _isListening ? Icons.stop : Icons.mic,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

                  // SEND BUTTON

                  Container(
                    width: 48,
                    height: 50,
                    decoration: BoxDecoration(
                      color: _isLoading ? Colors.grey : AppTheme.accent,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: IconButton(
                      onPressed: _isLoading
                          ? null
                          : () => _sendMessage(_controller.text),
                      icon: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                      ),
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

