import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const TextModerationApp());
}

class TextModerationApp extends StatelessWidget {
  const TextModerationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Text Moderation',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const TextModerationPage(),
    );
  }
}

class TextModerationPage extends StatefulWidget {
  const TextModerationPage({super.key});

  @override
  _TextModerationPageState createState() => _TextModerationPageState();
}



class _TextModerationPageState extends State<TextModerationPage> {
  final TextEditingController _textController = TextEditingController();
  String _result = '';
  bool _isLoading = false;
  double _saferValue = 0.005;
  String _base64Image = '';

  Future<void> _moderateText() async {
  setState(() {
    _isLoading = true;
    _result = 'Processing...';
  });

  try {
    final response = await http.post(
      Uri.parse('https://duchaba-friendly-text-moderation.hf.space/call/fetch_toxicity_level'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "data": [
          _textController.text,
          _saferValue
        ]
      }),
    );

    if (response.statusCode == 200) {
      final jsonData = _extractJsonFromSSE(response.body);
      
      if (jsonData != null) {
        final jsonResponse = jsonDecode(jsonData);
        final eventId = jsonResponse['event_id'];

        final resultResponse = await http.get(
          Uri.parse('https://duchaba-friendly-text-moderation.hf.space/call/fetch_toxicity_level/$eventId'),
        );

        if (resultResponse.statusCode == 200) {
          final resultData = _extractJsonFromSSE(resultResponse.body);
          print('Raw response: ${resultResponse.body}');
          print('Extracted JSON: $resultData');
          if (resultData != null) {
            final resultJson = jsonDecode(resultData);
            final analysisJson = jsonDecode(resultJson[1]);
            final String base64Image = resultJson[0]['plot'].split(',')[1]; // 
            setState(() {
              _result = _formatAnalysisResult(analysisJson);
              _base64Image = base64Image; // Store the base64 image data
            });
          } else {
            throw Exception('Failed to extract JSON from SSE in result');
          }
        } else {
          throw Exception('Failed to fetch result: ${resultResponse.statusCode}');
        }
      } else {
        throw Exception('Failed to extract JSON from SSE');
      }
    } else {
      throw Exception('Failed to initiate request: ${response.statusCode}');
    }
  } catch (e) {
    setState(() {
      _result = 'Error: $e';
    });
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

String? _extractJsonFromSSE(String sseData) {
  final lines = sseData.split('\n');
  for (var line in lines) {
    if (line.startsWith('data: ')) {
      return line.substring(6).trim();
    }
  }
  // If no 'data:' line is found, return the entire response
  return sseData.trim();
}





  String _formatAnalysisResult(Map<String, dynamic> analysis) {
    return '''
Is Flagged: ${analysis['is_flagged']}
Is Safer Flagged: ${analysis['is_safer_flagged']}
Max Category: ${analysis['max_key']}
Max Score: ${analysis['max_value'].toStringAsFixed(4)}
Total Score: ${analysis['sum_value'].toStringAsFixed(4)}

Detailed Scores:
${_formatScores(analysis)}

Message: ${analysis['message']}
''';
  }

  String _formatScores(Map<String, dynamic> analysis) {
    final scores = <String, double>{
      'Harassment': analysis['harassment'],
      'Hate': analysis['hate'],
      'Self-harm': analysis['self_harm'],
      'Sexual': analysis['sexual'],
      'Violence': analysis['violence'],
    };

    return scores.entries
        .map((e) => '${e.key}: ${e.value.toStringAsFixed(6)}')
        .join('\n');
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('Text Moderation'),
    ),
    body: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _textController,
            decoration: const InputDecoration(
              labelText: 'Enter text to moderate',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          Text('Safer Value: ${_saferValue.toStringAsFixed(3)}'),
          Slider(
            value: _saferValue,
            min: 0.001,
            max: 0.1,
            divisions: 99,
            label: _saferValue.toStringAsFixed(3),
            onChanged: (value) {
              setState(() {
                _saferValue = value;
              });
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isLoading ? null : _moderateText,
            child: _isLoading
                ? const CircularProgressIndicator()
                : const Text('Moderate Text'),
          ),
          const SizedBox(height: 16),
          Text(
            'Result:',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Text(_result),
                  if (_base64Image.isNotEmpty)
                    Image.memory(
                      base64Decode(_base64Image),
                      fit: BoxFit.contain,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

}
