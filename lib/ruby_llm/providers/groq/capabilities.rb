# frozen_string_literal: true

module RubyLLM
  module Providers
    module Groq
      # Determines capabilities and pricing for Groq models
      module Capabilities
        module_function

        MODEL_PATTERNS = {
          llama3_8b: /^llama3-8b/,
          llama3_70b: /^llama3-70b/,
          mixtral_8x7b: /^mixtral-8x7b/,
          gemma_7b: /^gemma-7b/,
          gemma_2b: /^gemma-2b/
        }.freeze

        def context_window_for(model_id)
          case model_family(model_id)
          when 'llama3_8b', 'llama3_70b' then 8_192
          when 'mixtral_8x7b' then 32_768
          when 'gemma_7b', 'gemma_2b' then 8_192
          else 4_096
          end
        end

        def max_tokens_for(model_id)
          case model_family(model_id)
          when 'llama3_8b', 'llama3_70b' then 4_096
          when 'mixtral_8x7b' then 8_192
          when 'gemma_7b', 'gemma_2b' then 4_096
          else 2_048
          end
        end

        def supports_vision?(model_id)
          false
        end

        def supports_functions?(model_id)
          case model_family(model_id)
          when 'llama3_8b', 'llama3_70b', 'mixtral_8x7b' then true
          else false
          end
        end

        def supports_structured_output?(model_id)
          case model_family(model_id)
          when 'llama3_8b', 'llama3_70b', 'mixtral_8x7b' then true
          else false
          end
        end

        def supports_json_mode?(model_id)
          supports_structured_output?(model_id)
        end

        PRICES = {
          llama3_8b: { input: 0.1, output: 0.2 },
          llama3_70b: { input: 0.7, output: 1.0 },
          mixtral_8x7b: { input: 0.27, output: 0.27 },
          gemma_7b: { input: 0.1, output: 0.2 },
          gemma_2b: { input: 0.05, output: 0.1 }
        }.freeze

        def model_family(model_id)
          MODEL_PATTERNS.each do |family, pattern|
            return family.to_s if model_id.match?(pattern)
          end
          'other'
        end

        def input_price_for(model_id)
          family = model_family(model_id).to_sym
          prices = PRICES.fetch(family, { input: default_input_price })
          prices[:input] || prices[:price] || default_input_price
        end

        def output_price_for(model_id)
          family = model_family(model_id).to_sym
          prices = PRICES.fetch(family, { output: default_output_price })
          prices[:output] || prices[:price] || default_output_price
        end

        def model_type(_model_id)
          'chat'
        end

        def default_input_price
          0.10
        end

        def default_output_price
          0.20
        end

        def format_display_name(model_id)
          model_id.then { |id| humanize(id) }
                  .then { |name| apply_special_formatting(name) }
        end

        def humanize(id)
          id.tr('-', ' ')
            .split
            .map(&:capitalize)
            .join(' ')
        end

        def apply_special_formatting(name)
          name
            .gsub(/Llama3/, 'Llama 3')
            .gsub(/Mixtral 8x7b/, 'Mixtral 8x7B')
            .gsub(/Gemma 7b/, 'Gemma 7B')
            .gsub(/Gemma 2b/, 'Gemma 2B')
        end

        def self.normalize_temperature(temperature, _model_id)
          temperature
        end

        def modalities_for(_model_id)
          {
            input: ['text'],
            output: ['text']
          }
        end

        def capabilities_for(model_id)
          capabilities = []

          # Common capabilities
          capabilities << 'streaming'
          capabilities << 'function_calling' if supports_functions?(model_id)
          capabilities << 'structured_output' if supports_json_mode?(model_id)

          capabilities
        end

        def pricing_for(model_id)
          standard_pricing = {
            input_per_million: input_price_for(model_id),
            output_per_million: output_price_for(model_id)
          }

          # Pricing structure
          { text_tokens: { standard: standard_pricing } }
        end
      end
    end
  end
end