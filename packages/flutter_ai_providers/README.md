# Flutter AI Toolkit Community Providers

[![flutter_ai_providers CI](https://github.com/davidmigloz/flutter_ai_community/actions/workflows/flutter_ai_providers_ci.yml/badge.svg)](https://github.com/davidmigloz/flutter_ai_community/actions/workflows/flutter_ai_providers_ci.yml)
[![flutter_ai_providers](https://img.shields.io/pub/v/flutter_ai_providers.svg)](https://pub.dev/packages/flutter_ai_providers)
[![MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://github.com/davidmigloz/langchain_dart/blob/main/LICENSE)

Community-contributed providers for the [Flutter AI Toolkit](https://github.com/flutter/ai). 

## Features

- 🤖 Multiple LLM Providers Support:
    - OpenAI (GPT-4o, o1, etc.)
    - Anthropic (Claude)
    - Ollama (Local Models)
- 💬 Streaming Responses: Real-time message streaming for a smooth chat experience
- 🖼️ Image Understanding: Support for image attachments in conversations

## Getting Started

### Installation

Add the following dependencies to your project:

```shell
flutter pub add flutter_ai_toolkit flutter_ai_providers
```

Or, if you prefer to do it manually, add the following to your `pubspec.yaml` file:

```yaml
dependencies:
  flutter_ai_toolkit: {version}
  flutter_ai_providers: {version}
```

### Usage

You can find a complete example in the official [Flutter AI Toolkit repository](https://github.com/flutter/ai/tree/main/example). Just replace the existing provider with the one you want to use.

## Providers

The following providers are currently supported:

> **Remember that your API key is a secret!**  
> Do not share it with others or expose it in any client-side code. Production requests must be routed through your own backend server where your API key can be securely loaded.

### OpenAI Provider

- [Website](https://platform.openai.com/docs)
- [Getting API key](https://platform.openai.com/api-keys)
- [Supported models](https://platform.openai.com/docs/models)

```dart
final provider = OpenAIProvider(
  apiKey: 'your-api-key',
  model: 'gpt-4o',
);
```

With this provider you can also consume OpenAI-compatible APIs like [OpenRouter](https://openrouter.ai), [xAI](https://docs.x.ai/), [Groq](https://groq.com/),[GitHub Models](https://github.com/marketplace/models), [TogetherAI](https://www.together.ai/), [Anyscale](https://www.anyscale.com/), [One API](https://github.com/songquanpeng/one-api), [Llamafile](https://llamafile.ai/), [GPT4All](https://gpt4all.io/), [FastChat](https://github.com/lm-sys/FastChat), etc. To do so, just replace the `baseUrl` parameter with the desired API endpoint and set the required `headers`. For example:

[OpenRouter](https://openrouter.ai):

```dart
final client = OpenAIProvider(
  baseUrl: 'https://openrouter.ai/api/v1',
  headers: { 'api-key': 'YOUR_OPEN_ROUTER_API_KEY' },
  model: 'meta-llama/llama-3.3-70b-instruct',
);
```

[xAI](https://docs.x.ai/):

```dart
final client = OpenAIClient(
  baseUrl: 'https://api.x.ai/v1',
  headers: { 'api-key': 'YOUR_XAI_API_KEY' },
  model: 'grok-beta',
);
```

[GitHub Models](https://github.com/marketplace/models):

```dart
final client = OpenAIClient(
  baseUrl: 'https://models.inference.ai.azure.com',
  headers: { 'api-key': 'YOUR_GITHUB_TOKEN' },
  model: 'Phi-3.5-MoE-instruct',
);
```

etc.

### Anthropic Provider

- [Website](https://docs.anthropic.com)
- [Getting API key](https://console.anthropic.com/settings/keys)
- [Supported models](https://docs.anthropic.com/en/docs/about-claude/models)

```dart
final provider = AnthropicProvider(
  apiKey: 'your-api-key',
  model: 'claude-3-opus-20240229',
);
```

### Ollama Provider

- [Website](https://ollama.com/)
- [Supported models](https://ollama.com/search)

```dart
final provider = OllamaProvider(
  model: 'llama3.2-vision',
);
```

### Openwebui Provider

- [Website](https://openwebui.com/)
- [Supported models](https://ollama.com/search)

```dart
final provider = OpenwebuiProvider(
  baseUrl: 'http://localhost:3000',
  apiKey: 'your-api-key',
  model: 'llama3.1:latest',
);
```

## Contributing

Contributions are welcome! If you'd like to add support for additional providers or improve existing ones, please feel free to submit a pull request.

## License

This package is licensed under the [MIT License](https://github.com/davidmigloz/flutter_ai_community/blob/main/LICENSE).
