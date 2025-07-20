# frozen_string_literal: true

module RubyLLM
  module Providers
    # Groq API integration. Handles chat completion, streaming,
    # and Groq's models. Supports Llama, Mixtral, and other Groq models.
    module Groq
      extend Provider
      extend Groq::Chat
      extend Groq::Models
      extend Groq::Streaming

      def self.extended(base)
        base.extend(Provider)
        base.extend(Groq::Chat)
        base.extend(Groq::Models)
        base.extend(Groq::Streaming)
      end

      module_function

      def api_base(_config)
        'https://api.groq.com/v1'
      end

      def headers(config)
        {
          'Authorization' => "Bearer #{config.groq_api_key}"
        }.compact
      end

      def capabilities
        Groq::Capabilities
      end

      def slug
        'groq'
      end

      def configuration_requirements
        %i[groq_api_key]
      end
    end
  end
end
