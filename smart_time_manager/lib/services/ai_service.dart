import 'dart:convert';
import 'package:http/http.dart' as http;

class AIService {
  // 1. Get API Key from: https://platform.deepseek.com/
  static const String _apiKey = 'sk-fwmlzyvkfqrhaiiniftlcctxwiwzpewpsgwqhpbhmdcajzsf'; 
  
  // 2. Base URL for SiliconFlow (OpenAI compatible)
  static const String _baseUrl = 'https://api.siliconflow.cn/v1/chat/completions';
  
  // 3. Model Name (DeepSeek V3 Chat Model via SiliconFlow)
  // Correct model ID for chat is 'deepseek-ai/DeepSeek-V3'
  // static const String _modelName = 'deepseek-ai/DeepSeek-V3';
  String _modelName = 'Qwen/Qwen3-8B';

  void setModel(String modelName) {
    _modelName = modelName;
  }

  String get currentModel => _modelName;

  AIService();

  /// Streaming response using standard HTTP (SSE-like logic simplified)
  /// Note: DeepSeek supports OpenAI-compatible stream. 
  /// For simplicity in Flutter without extra dependencies, we can use non-streaming first, 
  /// or implement simple streaming manually. 
  /// Here we implement NON-STREAMING first for stability, 
  /// as manual SSE parsing in Dart requires boilerplate.
  Stream<String> generateContentStream(String prompt) async* {
    try {
      final url = Uri.parse(_baseUrl);
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      };
      
      final now = DateTime.now();
      final dateStr = "${now.year}年${now.month}月${now.day}日";
      final weekday = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"][now.weekday - 1];
      
      final body = jsonEncode({
        'model': _modelName,
        'messages': [
          {
            'role': 'system', 
            'content': '''你是一个智能日程管理助手，请帮助用户规划时间、拆解任务。
当前日期是: $dateStr ($weekday)。
请用中文回答，条理清晰。
如果你的回答中包含具体的日程安排建议，请在回答的最后，务必使用 markdown 代码块输出一个 JSON 数组，格式如下：
```json
[
  {
    "title": "任务标题",
    "startTime": "YYYY-MM-DD HH:mm",
    "endTime": "YYYY-MM-DD HH:mm",
    "location": "地点（可选）",
    "isImportant": true/false,
    "isUrgent": true/false
  }
]
```
请确保日期时间格式准确，年份使用当前年份。'''
          },
          {'role': 'user', 'content': prompt}
        ],
        'stream': true, // Enable streaming
      });

      final request = http.Request('POST', url)
        ..headers.addAll(headers)
        ..body = body;

      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        yield "Error: ${response.statusCode} - ${response.reasonPhrase}";
        return;
      }

      // Parse SSE stream
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        // Chunk might contain multiple "data: {...}" lines
        final lines = chunk.split('\n');
        for (final line in lines) {
          if (line.startsWith('data: ')) {
            final data = line.substring(6).trim();
            if (data == '[DONE]') return;
            
            try {
              final json = jsonDecode(data);
              final content = json['choices']?[0]?['delta']?['content'];
              if (content != null) {
                yield content;
              }
            } catch (e) {
              // Ignore incomplete JSON chunks
            }
          }
        }
      }

    } catch (e) {
      print('AI Service Error: $e');
      yield "抱歉，无法连接到 DeepSeek 服务，请检查网络或 API Key 配置。";
    }
  }
}
