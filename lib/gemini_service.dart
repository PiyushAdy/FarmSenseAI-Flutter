import 'dart:convert';
import 'package:http/http.dart' as http;
import 'main.dart';
import 'app_config.dart';

class GeminiService {
  final String _apiUrl =
      "https://generativelanguage.googleapis.com/v1beta/models/${AppConstants.geminiModel}:generateContent";

  Future<String> getChatResponse({
    required String userQuery,
    List<Plant> plants = const [],
    Map<String, dynamic>? latestSensorData,
    String? base64Image,
  }) async {
    final plantsSummary = plants
        .map((p) =>
            "- ${p.name} (${p.type}) located at ${p.latitude}, ${p.longitude}")
        .join("\n");

    final prompt = """
    You are FarmSense AI, an expert farming assistant.
    **IMPORTANT**: You must strictly answer only farming-related questions. If the user asks about anything else, you must politely decline and state that you are a farming assistant.

    **User's Farm Context:**
    The user is managing the following plants:
    $plantsSummary

    ${latestSensorData != null ? "**Latest Sensor Reading:**\n"
        "- Temperature: ${latestSensorData['temp']}°C\n"
        "- Humidity: ${latestSensorData['humidity']}%\n"
        "- Soil Moisture: ${latestSensorData['moisture']}%\n"
        "- Light Level: ${latestSensorData['light']}%" : ""}

    **User's Query:** "$userQuery"
    
    ${base64Image != null ? "The user has also provided an image for analysis." : ""}

    Provide a helpful and concise answer. Format your response using Markdown.
    """;

    final List<Map<String, dynamic>> parts = [{'text': prompt}];
    if (base64Image != null) {
      parts.add({
        'inline_data': {'mime_type': 'image/jpeg', 'data': base64Image}
      });
    }

    return _generateContent(parts);
  }

  Future<String> getDiaryChatResponse({
    required String userQuery,
    List<DiaryEntry> entries = const [],
    String? base64Image,
  }) async {
    final diarySummary = entries
        .map((e) => "### ${e.title}\n${e.content}")
        .join("\n\n---\n\n");

    final prompt = """
    You are FarmSense AI, an expert farming assistant with access to the user's personal farm diary. 
    **IMPORTANT**: You must strictly answer only farming-related questions. If the user asks about anything else, you must politely decline and state that you are a farming assistant.

    **User's Diary Context:**
    Here are the user's diary entries, which contain their notes, observations, and plans:
    $diarySummary

    **User's Query:** "$userQuery"
    
    ${base64Image != null ? "The user has also provided an image for analysis." : ""}

    Based on the diary entries and the user's query, provide a helpful and concise answer. Format your response using Markdown.
    """;

    final List<Map<String, dynamic>> parts = [{'text': prompt}];
    if (base64Image != null) {
      parts.add({
        'inline_data': {'mime_type': 'image/jpeg', 'data': base64Image}
      });
    }

    return _generateContent(parts);
  }

  Future<String> getPlantHealthStatus(
      Plant plant, Map<String, dynamic>? sensorData) async {
    if (sensorData == null) return "Sensor values are not available.";
    final prompt =
        "Analyze the following sensor data for a ${plant.name} (${plant.type}) plant and provide a concise, one-sentence health status. Soil Type: ${plant.soilType}, Farming Practices: ${plant.farmingPractices}, Location: ${plant.latitude}, ${plant.longitude}, Temperature: ${sensorData['temp']}°C, Humidity: ${sensorData['humidity']}%, Soil Moisture: ${sensorData['moisture']}%, Light Level: ${sensorData['light']}%. Based on this data, is the plant 'Healthy', 'Stressed', or 'Needs Attention'? Provide only the status and a very brief reason.";
    return _generateContent([
      {'text': prompt}
    ]);
  }

  Future<String> getWeatherBasedSuggestions(
      Plant plant, Map<String, dynamic> weatherData) async {
    final prompt = """
    Analyze the weather for a '${plant.name}' plant and provide actionable suggestions.
    Current weather: ${weatherData['main']['temp']}°C, ${weatherData['weather'][0]['description']}.
    The response MUST be in Markdown format.
    Provide at most 5-6 pointers. Each pointer's topic MUST be in bold.
    Each pointer should not exceed 2-3 lines. Make it as concise as possible 
    Example:
    **Irrigation:** Water the plants in the morning to minimize evaporation and allow leaves to dry before nightfall, reducing disease risk.

    """;
    final response = await _generateContent([{'text': prompt}]);
    return response;
  }

  Future<String> getGovernmentSchemes(Plant plant) async {
    final prompt = """
    Find relevant government agricultural schemes for a farmer based on these details:
    - Plant: ${plant.name} (${plant.type})
    - Location: ${plant.latitude}, ${plant.longitude}
    The response MUST be in Markdown format.
    Provide at most 5-6 pointers. Each pointer's topic MUST be in bold, representing the scheme name.
    Each pointer should not exceed 2-3 lines, briefly mentioning benefits and eligibility & how to apply in sub pointers . these should be super concise in at max one sentence . Make it as concise as possible 
    If no schemes are found, return a message indicating that.
    """;
    final response = await _generateContent([
      {'text': prompt}
    ], useGoogleSearch: true);
    return response;
  }

  Future<String> getProductRecommendations(List<Plant> plants) async {
    final plantsSummary =
        plants.map((p) => "- Crop: ${p.name} (${p.type})").join("\n");
    final prompt =
        "You are an agricultural supplies advisor. You should Recommend things for farmer based out of india . Based on the farmer's plant portfolio:\n$plantsSummary\nRecommend 3-5 products (fertilizers, pesticides, tools). Provide details in a strict JSON array format: `[{\"product_name\": \"...\", \"average_price\": \"...\", \"required_quantity\": \"...\", \"relevant_plants\": [\"...\"]}]`. The response must be only the JSON array.";
    return _generateContent([
      {'text': prompt}
    ]);
  }

  Future<String> getPriceAndMarketAnalysis(Plant plant, String quantity) async {
    final prompt =
        "You are a leading agricultural market analyst AI. For a farmer selling '$quantity' of '${plant.name}' near ${plant.latitude}, ${plant.longitude}, provide a concise Markdown analysis including: a Suggested Price Range, a brief Market Trend Analysis, and Tips for the Farmer.";
    return _generateContent([
      {'text': prompt}
    ]);
  }

  Future<String> getMarketTrends(Plant plant) async {
    final prompt = """
    Provide a detailed market trend analysis for the following crop:
    - Crop: ${plant.name} (${plant.type})
    - Location: ${plant.latitude}, ${plant.longitude}
    The response MUST be in Markdown format.
    Provide at most 5-6 pointers. Each pointer's topic MUST be in bold.
    Each pointer should be of at max one sentence . Make it as concise as possible 
    Topics should cover aspects like current price, demand, drivers, and advice.
    """;
    final response = await _generateContent([
      {'text': prompt}
    ], useGoogleSearch: true);
    return response;
  }

  Future<String> _generateContent(List<Map<String, dynamic>> parts,
      {bool useGoogleSearch = false}) async {
    if (ApiKeys.geminiApiKey.startsWith("YOUR_") ||
        ApiKeys.geminiApiKey.length < 10) {
      return "Please add your Gemini API Key in `app_config.dart`.";
    }

    final Map<String, dynamic> requestBody = {
      'contents': [
        {'parts': parts}
      ],
      'generationConfig': {
        'temperature': 0.7,
        'topP': 0.95,
      }
    };

    if (useGoogleSearch) {
      requestBody['tools'] = [
        {'googleSearch': {}}
      ];
    }

    try {
      final response = await http.post(
        Uri.parse('$_apiUrl?key=${ApiKeys.geminiApiKey}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);

        final candidate = body['candidates'][0];

        if (candidate['content'] != null &&
            candidate['content']['parts'] != null) {
          final buffer = StringBuffer();
          for (final part in candidate['content']['parts']) {
            if (part['text'] != null) {
              buffer.write(part['text']);
            }
          }

          if (buffer.isNotEmpty) {
            // Trim potential markdown backticks for JSON responses
            return buffer
                .toString()
                .replaceAll("```json", "")
                .replaceAll("```", "")
                .trim();
          }
        }
        return "Sorry, I couldn't get a valid response. Please try again.";
      } else {
        print("Gemini API Error: ${response.body}");
        return "Error from AI. Status code: ${response.statusCode}\n\n${response.body}";
      }
    } catch (e) {
      print("Error calling Gemini API: $e");
      return "Error connecting to AI service.";
    }
  }
}