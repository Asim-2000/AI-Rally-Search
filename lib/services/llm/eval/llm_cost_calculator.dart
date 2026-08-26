import '../llm_provider_config.dart';

/// Pricing model representing per-million-token costs in USD.
class ModelPricing {
  final String modelName;
  final double promptCostPerMillion;
  final double completionCostPerMillion;

  const ModelPricing({
    required this.modelName,
    required this.promptCostPerMillion,
    required this.completionCostPerMillion,
  });

  /// Cost for a given number of prompt tokens in USD.
  double computePromptCost(int promptTokens) {
    return (promptTokens / 1000000.0) * promptCostPerMillion;
  }

  /// Cost for a given number of completion tokens in USD.
  double computeCompletionCost(int completionTokens) {
    return (completionTokens / 1000000.0) * completionCostPerMillion;
  }

  /// Total cost for prompt and completion tokens.
  double computeTotalCost(int promptTokens, int completionTokens) {
    return computePromptCost(promptTokens) + computeCompletionCost(completionTokens);
  }
}

/// Token cost calculator supporting Google Gemini, OpenAI, Anthropic, and custom rates.
class LlmCostCalculator {
  LlmCostCalculator._();

  /// Known model pricing database (USD per 1M tokens).
  static final Map<String, ModelPricing> _pricingTable = {
    // Google Gemini Models
    'gemini-1.5-flash': const ModelPricing(
      modelName: 'gemini-1.5-flash',
      promptCostPerMillion: 0.075,
      completionCostPerMillion: 0.30,
    ),
    'gemini-1.5-flash-8b': const ModelPricing(
      modelName: 'gemini-1.5-flash-8b',
      promptCostPerMillion: 0.0375,
      completionCostPerMillion: 0.15,
    ),
    'gemini-2.0-flash': const ModelPricing(
      modelName: 'gemini-2.0-flash',
      promptCostPerMillion: 0.10,
      completionCostPerMillion: 0.40,
    ),
    'gemini-2.0-flash-exp': const ModelPricing(
      modelName: 'gemini-2.0-flash-exp',
      promptCostPerMillion: 0.0,
      completionCostPerMillion: 0.0,
    ),
    'gemini-3.6-flash': const ModelPricing(
      modelName: 'gemini-3.6-flash',
      promptCostPerMillion: 0.10,
      completionCostPerMillion: 0.40,
    ),
    'gemini-1.5-pro': const ModelPricing(
      modelName: 'gemini-1.5-pro',
      promptCostPerMillion: 1.25,
      completionCostPerMillion: 5.00,
    ),

    // OpenAI Models
    'gpt-4o-mini': const ModelPricing(
      modelName: 'gpt-4o-mini',
      promptCostPerMillion: 0.15,
      completionCostPerMillion: 0.60,
    ),
    'gpt-4o': const ModelPricing(
      modelName: 'gpt-4o',
      promptCostPerMillion: 2.50,
      completionCostPerMillion: 10.00,
    ),
    'gpt-4.5-preview': const ModelPricing(
      modelName: 'gpt-4.5-preview',
      promptCostPerMillion: 75.00,
      completionCostPerMillion: 150.00,
    ),
    'o3-mini': const ModelPricing(
      modelName: 'o3-mini',
      promptCostPerMillion: 1.10,
      completionCostPerMillion: 4.40,
    ),

    // Anthropic Models
    'claude-3-5-sonnet-20241022': const ModelPricing(
      modelName: 'claude-3-5-sonnet-20241022',
      promptCostPerMillion: 3.00,
      completionCostPerMillion: 15.00,
    ),
    'claude-3-5-haiku-20241022': const ModelPricing(
      modelName: 'claude-3-5-haiku-20241022',
      promptCostPerMillion: 0.80,
      completionCostPerMillion: 4.00,
    ),

    // Mock Parser (Free)
    'mock-parser-v1': const ModelPricing(
      modelName: 'mock-parser-v1',
      promptCostPerMillion: 0.0,
      completionCostPerMillion: 0.0,
    ),
  };

  /// Register or override pricing for a specific model.
  static void registerPricing(ModelPricing pricing) {
    _pricingTable[pricing.modelName.toLowerCase()] = pricing;
  }

  /// Resolves the best-matching ModelPricing for a given model string or provider.
  static ModelPricing getPricing({
    String? model,
    LlmProvider? provider,
  }) {
    if (model != null) {
      final normalized = model.toLowerCase().replaceAll('models/', '');
      if (_pricingTable.containsKey(normalized)) {
        return _pricingTable[normalized]!;
      }

      // Fuzzy matching for versioned models (e.g. gemini-2.0-flash-001)
      for (final entry in _pricingTable.entries) {
        if (normalized.contains(entry.key)) {
          return entry.value;
        }
      }
    }

    // Default fallback by provider
    switch (provider) {
      case LlmProvider.gemini:
        return _pricingTable['gemini-2.0-flash']!;
      case LlmProvider.openai:
        return _pricingTable['gpt-4o-mini']!;
      case LlmProvider.anthropic:
        return _pricingTable['claude-3-5-haiku-20241022']!;
      case LlmProvider.mock:
      default:
        return _pricingTable['mock-parser-v1']!;
    }
  }

  /// Calculates total cost in USD for the provided token usage and model.
  static double calculateCost({
    required int promptTokens,
    required int completionTokens,
    String? model,
    LlmProvider? provider,
  }) {
    final pricing = getPricing(model: model, provider: provider);
    return pricing.computeTotalCost(promptTokens, completionTokens);
  }

  /// Formats a USD cost amount to human-readable string (e.g., "$0.000045" or "<$0.0001").
  static String formatCostUsd(double costUsd) {
    if (costUsd == 0.0) return '\$0.000000';
    if (costUsd < 0.000001) return '<\$0.000001';
    if (costUsd < 0.01) {
      return '\$${costUsd.toStringAsFixed(6)}';
    }
    return '\$${costUsd.toStringAsFixed(4)}';
  }

  /// Calculates estimated cost for 1,000 queries based on single query cost.
  static double estimateCostPerThousand(double costPerQueryUsd) {
    return costPerQueryUsd * 1000.0;
  }
}
