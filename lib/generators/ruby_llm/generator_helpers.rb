# frozen_string_literal: true

module RubyLLM
  module Generators
    # Shared helpers for RubyLLM generators
    module GeneratorHelpers
      # Log separator for visual organization
      LOG_SEPARATOR = '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'

      # Map RubyLLM modules to their canonical type names
      RUBY_LLM_MODULES = {
        RubyLLM::ActiveRecord::ChatMethods => 'Chat',
        RubyLLM::ActiveRecord::MessageMethods => 'Message',
        RubyLLM::ActiveRecord::ModelMethods => 'Model',
        RubyLLM::ActiveRecord::ToolCallMethods => 'ToolCall'
      }.freeze

      def parse_model_mappings
        @model_names = {
          chat: 'Chat',
          message: 'Message',
          tool_call: 'ToolCall',
          model: 'Model'
        }

        model_mappings.each do |mapping|
          if mapping.include?(':')
            key, value = mapping.split(':', 2)
            @model_names[key.to_sym] = value.classify
          end
        end

        @model_names
      end

      %i[chat message tool_call model].each do |type|
        define_method("#{type}_model_name") do
          @model_names ||= parse_model_mappings
          @model_names[type]
        end

        define_method("#{type}_table_name") do
          table_name_for(send("#{type}_model_name"))
        end

        define_method("#{type}_variable_name") do
          variable_name_for(send("#{type}_model_name"))
        end

        define_method("#{type}_controller_class_name") do
          controller_class_name_for(send("#{type}_model_name"))
        end

        define_method("#{type}_job_class_name") do
          "#{variable_name_for(send("#{type}_model_name")).camelize}ResponseJob"
        end

        define_method("#{type}_partial") do
          partial_path_for(send("#{type}_model_name"))
        end
      end

      def acts_as_chat_declaration
        params = []

        add_association_params(params, :messages, message_table_name, message_model_name, plural: true)
        add_association_params(params, :model, model_table_name, model_model_name)

        "acts_as_chat#{" #{params.join(', ')}" if params.any?}"
      end

      def acts_as_message_declaration
        params = []

        add_association_params(params, :chat, chat_table_name, chat_model_name)
        add_association_params(params, :tool_calls, tool_call_table_name, tool_call_model_name, plural: true)
        add_association_params(params, :model, model_table_name, model_model_name)

        "acts_as_message#{" #{params.join(', ')}" if params.any?}"
      end

      def acts_as_model_declaration
        params = []

        add_association_params(params, :chats, chat_table_name, chat_model_name, plural: true)

        "acts_as_model#{" #{params.join(', ')}" if params.any?}"
      end

      def acts_as_tool_call_declaration
        params = []

        add_association_params(params, :message, message_table_name, message_model_name)

        "acts_as_tool_call#{" #{params.join(', ')}" if params.any?}"
      end

      def create_namespace_modules
        namespaces = []

        [chat_model_name, message_model_name, tool_call_model_name, model_model_name].each do |model_name|
          if model_name.include?('::')
            namespace = model_name.split('::').first
            namespaces << namespace unless namespaces.include?(namespace)
          end
        end

        namespaces.each do |namespace|
          module_path = "app/models/#{namespace.underscore}.rb"
          next if File.exist?(Rails.root.join(module_path))

          create_file module_path do
            <<~RUBY
              module #{namespace}
                def self.table_name_prefix
                  "#{namespace.underscore}_"
                end
              end
            RUBY
          end
        end
      end

      def migration_version
        "[#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}]"
      end

      def postgresql?
        ::ActiveRecord::Base.connection.adapter_name.downcase.include?('postgresql')
      rescue StandardError
        false
      end

      def table_exists?(table_name)
        ::ActiveRecord::Base.connection.table_exists?(table_name)
      rescue StandardError
        false
      end

      private

      def add_association_params(params, default_assoc, table_name, model_name, plural: false)
        assoc = plural ? table_name.to_sym : table_name.singularize.to_sym

        return if assoc == default_assoc

        params << "#{default_assoc}: :#{assoc}"
        params << "#{default_assoc.to_s.singularize}_class: '#{model_name}'" if model_name != assoc.to_s.classify
      end

      # Convert namespaced model names to proper table names
      # First tries to load the actual model and get its table_name
      # Falls back to convention-based inference if model doesn't exist yet
      # e.g., "Assistant::Chat" -> "assistant_chats" (not "assistant/chats")
      def table_name_for(model_name)
        # Use cached model table names if available
        return ruby_llm_model_tables[model_name] if ruby_llm_model_tables.key?(model_name)

        # Not in Rails environment or no model found - try constantize anyway
        begin
          model_class = model_name.constantize
          if model_class.respond_to?(:table_name)
            table_name = model_class.table_name
            puts "✓ Found via constantize: #{model_name} => #{table_name}"
            return table_name
          end
        rescue NameError, LoadError => e
          puts "⚠ Could not constantize #{model_name}: #{e.message}"
        end

        # Model doesn't exist yet (e.g., during initial install)
        # or couldn't be loaded - fall back to convention-based inference
        inferred_name = model_name.underscore.pluralize.tr('/', '_')
        puts "→ Falling back to inference: #{model_name} => #{inferred_name}"
        inferred_name
      end

      private

      # Discover RubyLLM models by eager-loading Rails app
      # Returns a hash of model_name => table_name for models using acts_as_* macros
      def ruby_llm_model_tables
        @ruby_llm_model_tables ||= begin
          tables = {}
          # Only scan if we're in a Rails environment with a bootable app
          if defined?(Rails) && Rails.respond_to?(:root) && !Rails.env.nil?
            puts LOG_SEPARATOR
            puts 'Starting model discovery...'
            puts LOG_SEPARATOR

            begin
              # Boot Rails environment if not already booted
              if Rails.application.initialized?
                puts "✓ Rails application already initialized"
              else
                puts "→ Booting Rails environment..."
                require Rails.root.join('config/environment')
                puts "✓ Rails environment booted"
              end

              # Eager-load all models so descendants are available
              puts '→ Eager-loading models...'
              Rails.application.eager_load!

              # Find all AR models
              base_class = defined?(ApplicationRecord) ? ApplicationRecord : ActiveRecord::Base
              models = base_class.descendants.reject(&:abstract_class?)

              puts '→ Scanning for RubyLLM models...'

              models.each do |model_class|
                # Check which RubyLLM module this model includes
                ruby_llm_type = RUBY_LLM_MODULES.find do |mod, _type_name|
                  model_class.included_modules.include?(mod)
                end&.last

                next unless ruby_llm_type

                # Map the RubyLLM type (Chat, Message, etc.) to this app's table name
                tables[ruby_llm_type] = model_class.table_name
                puts "  ✓ #{ruby_llm_type} (#{model_class.name}) => #{model_class.table_name}"
              end

              puts LOG_SEPARATOR
              puts "✓ Discovery complete: Found #{tables.count} RubyLLM models"
              puts LOG_SEPARATOR
            rescue StandardError => e
              puts LOG_SEPARATOR
              puts '✗ Error during model discovery'
              puts LOG_SEPARATOR
              puts "Error class: #{e.class}"
              puts "Error message: #{e.message}"
              puts '→ Will fall back to inference for table names'
              puts LOG_SEPARATOR
              # If eager loading fails, we'll fall back to inference
              # This can happen during initial install when DB isn't set up yet
            end
          end

          tables
        end
      end

      # Convert model name to instance variable name
      # e.g., "LLM::Chat" -> "llm_chat" (not "llm/chat")
      def variable_name_for(model_name)
        model_name.underscore.tr('/', '_')
      end

      # Convert model name to controller class name
      # For namespaced models, use Rails convention: "Llm::Chat" -> "Llm::ChatsController"
      # For regular models: "Chat" -> "ChatsController"
      def controller_class_name_for(model_name)
        if model_name.include?('::')
          parts = model_name.split('::')
          namespace = parts[0..-2].join('::')
          resource = parts.last.pluralize
          "#{namespace}::#{resource}Controller"
        else
          "#{model_name.pluralize}Controller"
        end
      end

      # Convert model name to partial path
      # e.g., "LLM::Message" -> "llm/message" (not "llm_message")
      def partial_path_for(model_name)
        "#{model_name.underscore.pluralize}/#{model_name.demodulize.underscore}"
      end
    end
  end
end
