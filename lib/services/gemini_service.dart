import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {
  // 🔥 তোর Groq API Key এখানে দে
  static const String _apiKey = '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';

  static Future<String> getDailyTask(String type) async {
    try {
      String base = "I am a teenage student in Bangladesh. Give me ONE highly actionable, practical task for today. Do not give generic advice. Give a specific, slightly uncomfortable challenge. Maximum 2 short sentences. Answer in friendly conversational Bengali font. ";
      
      String specificPrompt = "";
      if (type == 'conf') {
        specificPrompt = base + "Topic: Build extreme self-confidence and kill social anxiety (e.g., talk to a stranger, ask a bold question).";
      } else if (type == 'story') {
        specificPrompt = base + "Topic: Improve storytelling and communication (e.g., explain a mundane daily event to a friend in a cinematic/dramatic way).";
      } else if (type == 'humor') {
        specificPrompt = base + "Topic: Develop a sharp sense of humor and quick wit (e.g., observe a funny situation and make a joke out of it).";
      } else if (type == 'ei') {
        specificPrompt = base + "Topic: Build Emotional Intelligence (e.g., practice active listening to mom without interrupting).";
      }

      // 🔥 Groq API এন্ডপয়েন্ট
      final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey', // Bearer টোকেন হিসেবে Groq Key
        },
        body: jsonEncode({
          "model": "mixtral-8x7b-32768", // 🔥 Groq এর সুপারফাস্ট Llama 3 মডেল
          "messages": [
            {"role": "user", "content": specificPrompt}
          ],
          "temperature": 0.7
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String result = data['choices'][0]['message']['content'];
        return result.replaceAll(RegExp(r'\*'), '').trim();
      } else {
        final errorData = jsonDecode(response.body);
        return "API Error: ${errorData['error']['message']}";
      }
    } catch (e) {
      return "ইন্টারনেট কানেকশন নেই অথবা এরর: $e";
    }
  }
}