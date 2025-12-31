import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:prepskul/core/services/log_service.dart';
import 'package:prepskul/core/config/app_config.dart';

/// Service for on-demand AI image generation for games
/// Integrates with OpenRouter image generation models
class ImageGenerationService {
  static const String _baseUrl = 'https://openrouter.ai/api/v1/chat/completions';
  
  /// Generate a concept image using AI
  /// Returns image URL or null if generation fails
  /// 
  /// [concept] - The concept to visualize (e.g., "mitochondria", "Ohm's Law circuit")
  /// [context] - Additional context from the notes (optional)
  static Future<String?> generateConceptImage({
    required String concept,
    String? context,
  }) async {
    try {
      final apiKey = _getApiKey();
      if (apiKey == null || apiKey.isEmpty) {
        LogService.warning('🎨 [ImageGen] API key not configured');
        return null;
      }

      // Build prompt for image generation
      String prompt = 'Create an educational diagram or illustration of: $concept';
      if (context != null && context.isNotEmpty) {
        prompt += '. Context: ${context.substring(0, context.length > 200 ? 200 : context.length)}';
      }
      prompt += '. Style: Clear, educational, labeled diagram suitable for learning.';

      LogService.info('🎨 [ImageGen] Generating image for: $concept');

      // Try image generation models in order of preference
      final imageModels = [
        'black-forest-labs/flux-1.1-pro',      // Best quality
        'stability-ai/stable-diffusion-xl',   // Good quality
        'openai/dall-e-3',                    // OpenAI model
      ];

      for (final model in imageModels) {
        try {
          final response = await http.post(
            Uri.parse(_baseUrl),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
              'HTTP-Referer': AppConfig.appBaseUrl,
              'X-Title': 'PrepSkul Image Generation',
            },
            body: jsonEncode({
              'model': model,
              'messages': [
                {
                  'role': 'user',
                  'content': prompt,
                },
              ],
              'max_tokens': 1000,
            }),
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            final choices = data['choices'] as List<dynamic>?;
            
            if (choices != null && choices.isNotEmpty) {
              final message = choices[0]['message'] as Map<String, dynamic>?;
              final content = message?['content'] as String?;
              
              // Extract image URL from response
              // OpenRouter image models may return URLs or base64
              if (content != null) {
                // Try to extract URL from content
                final urlMatch = RegExp(r'https?://[^\s]+').firstMatch(content);
                if (urlMatch != null) {
                  final imageUrl = urlMatch.group(0);
                  LogService.success('🎨 [ImageGen] Image generated: $imageUrl');
                  return imageUrl;
                }
                
                // If base64, we'd need to upload to Supabase Storage
                // For now, return null and let the game use placeholder
                LogService.warning('🎨 [ImageGen] Base64 image not yet supported');
              }
            }
          } else if (response.statusCode == 402) {
            LogService.warning('🎨 [ImageGen] Credits required for $model');
            continue; // Try next model
          } else {
            LogService.warning('🎨 [ImageGen] Model $model failed: ${response.statusCode}');
            continue; // Try next model
          }
        } catch (e) {
          LogService.warning('🎨 [ImageGen] Error with $model: $e');
          continue; // Try next model
        }
      }

      LogService.warning('🎨 [ImageGen] All models failed');
      return null;
    } catch (e) {
      LogService.error('🎨 [ImageGen] Error generating image: $e');
      return null;
    }
  }

  /// Get OpenRouter API key from environment
  static String? _getApiKey() {
    // Try to get from environment variables
    // This should be set in .env or injected at runtime
    try {
      // For Flutter web, we might need to read from window.env
      // For mobile, use dotenv
      // For now, return null - API key should be configured server-side
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Generate multiple images for a list of concepts
  /// Returns a map of concept -> image URL
  static Future<Map<String, String?>> generateConceptImages(
    List<String> concepts, {
    Map<String, String>? contextMap,
  }) async {
    final results = <String, String?>{};
    
    for (final concept in concepts) {
      final context = contextMap?[concept];
      final imageUrl = await generateConceptImage(
        concept: concept,
        context: context,
      );
      results[concept] = imageUrl;
    }
    
    return results;
  }
}
