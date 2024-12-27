import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:http/http.dart' as http;

/// Internal open-webui json encoder / decoder
extension _OwuiMessage on ChatMessage {
  /// Converts the [ChatMessage] instance to a JSON object.
  Map<String, dynamic> toOwuiJson() => {
    'role': origin == MessageOrigin.user ? 'user' : 'assistant',
    'content': text,
    'files': [
      /// ... Figure out how to handle attachments
    ]
  };

  /// Creates an instance of [ChatMessage] from a JSON object.
  static fromOwuiJson(Map<String, dynamic> json) {
    return ChatMessage(
      origin: json['role'] == 'user' ? MessageOrigin.user : MessageOrigin.llm,
      text: json['delta']?['content'],
      attachments: [],
    );
  }
}

/// Internal open-webui json encoder / decoder
/// Encode a request to the open-webui API.
class _OwuiChatRequest {
  final String model;
  final List<ChatMessage> messages;
  final List<Map<String, dynamic>>? files;

  /// Creates an instance of [_OwuiChatRequest].
  ///
  /// [model] is the model to be used for the chat.
  /// [messages] is the list of messages in the chat history.
  _OwuiChatRequest({required this.model, required this.messages, this.files});

  /// Converts the [_OwuiChatRequest] instance to a JSON object.
  Map<String, dynamic> toJson() => {
    'model': model,
    'stream': true,
    'messages': messages.map((message) => message.toOwuiJson()).toList(),
    'files': files,
  };

  String toJsonString() => jsonEncode(toJson());
}

/// Internal open-webui json encoder / decoder
/// Decode a chat response from the open-webui API.
class _OwuiChatResponse {
  final List<_OwuiChatResponseChoice> choices;

  /// Creates an instance of [_OwuiChatResponse].
  ///
  /// [choices] is the list of choices in the response.
  _OwuiChatResponse({required this.choices});

  /// Creates an instance of [_OwuiChatResponse] from a JSON object.
  factory _OwuiChatResponse.fromJson(Map<String, dynamic> json) {
    return _OwuiChatResponse(
      choices: (json['choices'] as List).map((choice) => _OwuiChatResponseChoice.fromJson(choice)).toList(),
    );
  }

  factory _OwuiChatResponse.fromJsonString(String jsonString) {
    return _OwuiChatResponse.fromJson(jsonDecode(jsonString));
  }
}

/// Internal open-webui json encoder / decoder
/// Decoder for the choice part of [_OwuiChatResponse].
class _OwuiChatResponseChoice {
  final ChatMessage message;

  /// Creates an instance of [_OwuiChatResponseChoice].
  ///
  /// [message] is the message in the choice.
  _OwuiChatResponseChoice({required this.message});

  /// Creates an instance of [_OwuiChatResponseChoice] from a JSON object.
  factory _OwuiChatResponseChoice.fromJson(Map<String, dynamic> json) {
    return _OwuiChatResponseChoice(
      message: _OwuiMessage.fromOwuiJson(json),
    );
  }
}


/// A provider for [open-webui](https://openwebui.com/)
/// Use open-webui as unified chat provider.
class OpenwebuiProvider extends LlmProvider with ChangeNotifier {
  /// Creates an [OpenwebuiProvider] instance with an optional chat history.
  ///
  /// The [history] parameter is an optional iterable of [ChatMessage] objects
  /// representing the chat history
  /// The [model] parameter is the ai model to be used for the chat.
  /// The [baseUrl] parameter is the host of the open-webui server.
  /// For example port 3000 on localhost use 'http://localhost:3000'
  /// The [apiKey] parameter is the API key for the open-webui server.
  /// See the [docs](https://docs.openwebui.com/) for more information.
  /// Example:
  /// ``` dart
  /// LlmChatView(
  ///   provider: OpenwebuiProvider(
  ///     host: 'http://127.0.0.1:3000',
  ///     model: 'llama3.1:latest',
  ///     apiKey: "YOUR_API_KEY",
  ///     history: [],
  ///   ),
  /// )
  /// ```
  OpenwebuiProvider({
    Iterable<ChatMessage>? history,
    required String model,
    required String baseUrl,
    String? apiKey,
  }): _history = history?.toList() ?? [],
      _model = model,
      _host = baseUrl,
      _apiKey = apiKey;

  final List<ChatMessage> _history;
  final String _model;
  final String _host;
  final String? _apiKey;
  final List<Map<String, String>> _attachments = [];
  final _emptyMessage = ChatMessage(origin: MessageOrigin.llm, text: null, attachments: []);

  @override
  Stream<String> generateStream(
    String prompt, {
    Iterable<Attachment> attachments = const [],
  }) async* {
    final userMessage = ChatMessage(text: prompt, attachments: attachments, origin: MessageOrigin.user);
    final llmMessage = ChatMessage(text: "", attachments: [], origin: MessageOrigin.llm);
    
    yield* _generateStream([userMessage, llmMessage]);
    
    notifyListeners();
  }

  @override
  Stream<String> sendMessageStream(
    String prompt, {
    Iterable<Attachment> attachments = const [],
  }) async* {
    final userMessage = ChatMessage(text: prompt, attachments: attachments, origin: MessageOrigin.user);
    final llmMessage = ChatMessage(text: null, attachments: [], origin: MessageOrigin.llm);
    _history.addAll([userMessage, llmMessage]);

    yield* _generateStream(_history);
    notifyListeners();
  }

  Stream<String> _generateStream(List<ChatMessage> messages) async* {
    final files = messages.lastWhere((m) => m.origin == MessageOrigin.user, orElse: () => _emptyMessage).attachments;
    final llmMessage = messages.last;
    if(files.isNotEmpty) {
      for (var file in files) {
        _attachments.add(await _uploadAttachment(file));
      }
    }

    final httpRequest = http.Request('POST', Uri.parse("$_host/chat/completions"))
      ..headers.addAll({
        if(_apiKey != null) 'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      })
      ..body = _OwuiChatRequest(
        model: _model,
        messages: messages.where((m) => m.text != null).toList(),
        files: _attachments,
      ).toJsonString();

    final httpResponse = await http.Client().send(httpRequest);

    if (httpResponse.statusCode == 200) {
      await for (var text in httpResponse.stream.transform(utf8.decoder)) {
        final messages = text.split('\n');
        for (var message in messages) {
          if (message.startsWith('data: [DONE]')) {
            return;
          }
          if (message.isEmpty) continue;
          final cleanedMessage = message.replaceFirst('data: ', '').trim();
          try {
            final chatResponse = _OwuiChatResponse.fromJsonString(cleanedMessage);
            for (var choice in chatResponse.choices) {
              llmMessage.append(choice.message.text ?? '');
              yield choice.message.text ?? '';
            }
          } catch (e) {
            // just skip?
          }
        }
        llmMessage.append('');
        yield '';
      }
    } else {
      throw Exception('HTTP request failed. Status: ${httpResponse.statusCode}, Reason: ${httpResponse.reasonPhrase}');
    }
  }

  Future<Map<String, String>> _uploadAttachment(Attachment filePath) async {
    if(filePath is! FileAttachment) {
      throw Exception('Unsupported attachment type');
    }

    final uri = Uri.parse('$_host/v1/files/'); // Replace with your OpenWebUI endpoint
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll({
        if(_apiKey != null) 'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'multipart/form-data',
        'Accept': 'application/json',
      })
      ..files.add(http.MultipartFile.fromBytes('file', filePath.bytes, filename: filePath.name));

    final response = await request.send();
    if (response.statusCode == 200) {
      final responseBody = await response.stream.bytesToString();
      final jsonResponse = json.decode(responseBody);
      return {
        'type': 'file',
        'id': jsonResponse['id'].toString()
      }; // Adjust based on the actual response structure
    } else {
      throw Exception('Failed to upload file: ${response.reasonPhrase}');
    }
  }

  @override
  get history => List.from(_history);

  @override
  set history(history) {
    _history.clear();
    _history.addAll(history);
    notifyListeners();
  }
}
