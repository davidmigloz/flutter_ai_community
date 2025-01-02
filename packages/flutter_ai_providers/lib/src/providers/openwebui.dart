import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:http/http.dart' as http;

/// A provider for [Open WebUI](https://openwebui.com/).
/// Use open-webui as unified chat provider.
class OpenWebUIProvider extends LlmProvider with ChangeNotifier {
  /// Creates an [OpenWebUIProvider] instance with an optional chat history.
  ///
  /// The [history] parameter is an optional iterable of [ChatMessage] objects
  /// representing the chat history.
  /// The [model] parameter is the ai model to be used for the chat.
  /// The [baseUrl] parameter is the base url of the open-webui server API.
  /// For example port 3000 on localhost use 'http://localhost:3000'
  /// The [apiKey] parameter is the API key for the open-webui server.
  /// See the [docs](https://docs.openwebui.com/) for more information.
  ///
  /// Example:
  /// ``` dart
  /// LlmChatView(
  ///   provider: OpenWebUIProvider(
  ///     model: 'llama3.1:latest',
  ///     apiKey: "YOUR_API_KEY",
  ///   ),
  /// )
  /// ```
  OpenWebUIProvider({
    Iterable<ChatMessage>? history,
    required String model,
    String baseUrl = 'http://localhost:3000/api',
    String? apiKey,
  })  : _history = history?.toList() ?? [],
        _model = model,
        _host = baseUrl,
        _apiKey = apiKey;

  final List<ChatMessage> _history;
  final String _model;
  final String _host;
  final String? _apiKey;
  final List<_OwuiFileAttachment> _fileAttachments = [];
  final List<_OwuiImageAttachment> _imageAttachments = [];
  final _emptyMessage = ChatMessage(
    origin: MessageOrigin.llm,
    text: null,
    attachments: [],
  );

  @override
  Stream<String> generateStream(
    String prompt, {
    Iterable<Attachment> attachments = const [],
  }) async* {
    final userMessage = ChatMessage.user(prompt, attachments);
    final llmMessage = ChatMessage.llm();

    yield* _generateStream([userMessage, llmMessage]);
  }

  @override
  Stream<String> sendMessageStream(
    String prompt, {
    Iterable<Attachment> attachments = const [],
  }) async* {
    final userMessage = ChatMessage.user(prompt, attachments);
    final llmMessage = ChatMessage.llm();
    _history.addAll([userMessage, llmMessage]);

    yield* _generateStream(_history);
  }

  Stream<String> _generateStream(List<ChatMessage> messages) async* {
    final files = messages
        .lastWhere((m) => m.origin == MessageOrigin.user,
            orElse: () => _emptyMessage)
        .attachments;
    final llmMessage = messages.last;
    if (files.isNotEmpty) {
      for (var file in files) {
        await _handleAttachment(file);
      }
    }

    final httpRequest = http.Request(
        'POST', Uri.parse("$_host/chat/completions"))
      ..headers.addAll({
        if (_apiKey != null) 'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      })
      ..body = _OwuiChatRequest(
        model: _model,
        messages: messages.where((m) => m.text != null).toList(growable: false),
        files: _fileAttachments,
        images: _imageAttachments,
      ).toJsonString();

    final httpResponse = await http.Client().send(httpRequest);
    if (httpResponse.statusCode == 200) {
      await for (final message in httpResponse.stream
          .toStringStream()
          .transform(const LineSplitter())) {
        if (message.startsWith('data: [DONE]')) {
          return;
        }
        if (message.isEmpty) continue;
        final cleanedMessage = message.replaceFirst('data: ', '').trim();
        final chatResponse = _OwuiChatResponse.fromJsonString(cleanedMessage);
        for (var choice in chatResponse.choices) {
          llmMessage.append(choice.message.text ?? '');
          yield choice.message.text ?? '';
        }
      }
    } else {
      throw Exception(
        'HTTP request failed. '
        'Status: ${httpResponse.statusCode}, '
        'Reason: ${httpResponse.reasonPhrase}',
      );
    }
  }

  Future<void> _handleAttachment(Attachment attachment) async {
    if (attachment is ImageFileAttachment) {
      // Only one image can be attached at a time? At least with llama3.2-vision + ollama.
      _imageAttachments
        ..clear()
        ..add(_OwuiImageAttachment.fromImageAttachment(attachment));
    } else if (attachment is FileAttachment) {
      final uri = Uri.parse('$_host/v1/files');
      final request = http.MultipartRequest('POST', uri)
        ..headers.addAll({
          if (_apiKey != null) 'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'multipart/form-data',
          'Accept': 'application/json',
        })
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          attachment.bytes,
          filename: attachment.name,
        ));

      final response = await request.send();
      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final jsonResponse = json.decode(responseBody);
        _fileAttachments.add(_OwuiFileAttachment(
          type: 'file',
          id: jsonResponse['id'].toString(),
        ));
      } else {
        throw Exception('Failed to upload file: ${response.reasonPhrase}');
      }
    }
  }

  @override
  Iterable<ChatMessage> get history => List.from(_history);

  @override
  set history(Iterable<ChatMessage> history) {
    _history.clear();
    _history.addAll(history);
    notifyListeners();
  }
}

/// Internal open-webui json encoder / decoder
extension _OwuiMessage on ChatMessage {
  /// Converts the [ChatMessage] instance to a JSON object.
  Map<String, dynamic> toOwuiJson([List<Map<String, dynamic>>? images]) => {
        'role': origin == MessageOrigin.user ? 'user' : 'assistant',
        'content': images == null
            ? text
            : [
                {'text': text, 'type': 'text'},
                ...images
              ],
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

/// Internal open-webui json encoder / decoder.
/// Encode a request to the open-webui API.
class _OwuiChatRequest {
  /// Creates an instance of [_OwuiChatRequest].
  ///
  /// [model] is the model to be used for the chat.
  /// [messages] is the list of messages in the chat history.
  /// [files] files to be attached to the next request.
  /// [images] images to be attached to the next request.
  _OwuiChatRequest({
    required this.model,
    required this.messages,
    this.files,
    this.images,
  });

  final String model;
  final List<ChatMessage> messages;
  final List<_OwuiFileAttachment>? files;
  final List<_OwuiImageAttachment>? images;

  /// Converts the [_OwuiChatRequest] instance to a JSON object.
  Map<String, dynamic> toJson() => {
        'model': model,
        'stream': true,
        'messages': messages
            .map((message) => message.toOwuiJson(message ==
                    messages.firstWhere((m) => m.origin == MessageOrigin.user)
                ? images?.map((image) => image.toJson()).toList(growable: false)
                : null))
            .toList(growable: false),
        'files': files?.map((file) => file.toJson()).toList(growable: false),
      };

  String toJsonString() => jsonEncode(toJson());
}

/// Internal open-webui json encoder / decoder.
/// Decode a chat response from the open-webui API.
class _OwuiChatResponse {
  /// Creates an instance of [_OwuiChatResponse].
  ///
  /// [choices] is the list of choices in the response.
  _OwuiChatResponse({required this.choices});

  final List<_OwuiChatResponseChoice> choices;

  /// Creates an instance of [_OwuiChatResponse] from a JSON object.
  factory _OwuiChatResponse.fromJson(Map<String, dynamic> json) {
    return _OwuiChatResponse(
      choices: (json['choices'] as List?)
              ?.map((choice) => _OwuiChatResponseChoice.fromJson(choice))
              .toList() ??
          [],
    );
  }

  factory _OwuiChatResponse.fromJsonString(String jsonString) {
    return _OwuiChatResponse.fromJson(jsonDecode(jsonString));
  }
}

/// Internal open-webui json encoder / decoder
/// Decoder for the choice part of [_OwuiChatResponse].
class _OwuiChatResponseChoice {
  /// Creates an instance of [_OwuiChatResponseChoice].
  ///
  /// [message] is the message in the choice.
  _OwuiChatResponseChoice({required this.message});

  final ChatMessage message;

  /// Creates an instance of [_OwuiChatResponseChoice] from a JSON object.
  factory _OwuiChatResponseChoice.fromJson(Map<String, dynamic> json) {
    return _OwuiChatResponseChoice(
      message: _OwuiMessage.fromOwuiJson(json),
    );
  }
}

/// Internal open-webui json encoder / decoder
class _OwuiImageAttachment {
  _OwuiImageAttachment({
    required this.type,
    required this.imageUrl,
    required this.name,
  });

  final String type;
  final Map<String, String> imageUrl;
  final String name;

  Map<String, dynamic> toJson() => {
        'type': type,
        'image_url': imageUrl,
        'name': name,
      };

  factory _OwuiImageAttachment.fromImageAttachment(
      ImageFileAttachment attachment) {
    final base64Image = base64Encode(attachment.bytes);
    return _OwuiImageAttachment(
      type: 'image_url',
      imageUrl: {'url': "data:${attachment.mimeType};base64,$base64Image"},
      name: attachment.name,
    );
  }
}

/// Internal open-webui json encoder / decoder
class _OwuiFileAttachment {
  _OwuiFileAttachment({
    required this.type,
    required this.id,
  });

  final String type;
  final String id;

  Map<String, dynamic> toJson() => {
        'type': type,
        'id': id,
      };
}
