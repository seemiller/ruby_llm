# frozen_string_literal: true

require 'spec_helper'
require 'generators/ruby_llm/generator_helpers'

RSpec.describe RubyLLM::Generators::GeneratorHelpers do
  let(:test_class) do
    Class.new do
      include RubyLLM::Generators::GeneratorHelpers

      def initialize
        @model_names = { message: 'Message' }
      end
    end
  end

  let(:helper) { test_class.new }

  describe '#table_name_for' do
    context 'with a model that has custom table_name' do
      before do
        # Mock a model class with custom table_name
        model_class = Class.new do
          def self.table_name
            'chat_messages'
          end
        end
        stub_const('Message', model_class)
      end

      it 'returns the actual table_name from the model' do
        result = helper.send(:table_name_for, 'Message')
        expect(result).to eq('chat_messages')
      end
    end

    context 'with a namespaced model overriding convention' do
      before do
        # Mock namespace and model with custom table_name
        stub_const('AI', Module.new)
        model_class = Class.new do
          def self.table_name
            'messages' # Override namespace convention
          end
        end
        stub_const('AI::Message', model_class)
      end

      it 'returns the actual table_name, not the namespace-inferred name' do
        result = helper.send(:table_name_for, 'AI::Message')
        expect(result).to eq('messages')
      end
    end

    context 'with a model using legacy table naming' do
      before do
        model_class = Class.new do
          def self.table_name
            'tbl_messages' # Legacy prefix
          end
        end
        stub_const('LegacyMessage', model_class)
      end

      it 'respects legacy table naming' do
        result = helper.send(:table_name_for, 'LegacyMessage')
        expect(result).to eq('tbl_messages')
      end
    end

    context 'with a model that follows Rails conventions' do
      before do
        model_class = Class.new do
          def self.table_name
            'standard_messages' # Rails convention
          end
        end
        stub_const('StandardMessage', model_class)
      end

      it 'returns the conventional table name' do
        result = helper.send(:table_name_for, 'StandardMessage')
        expect(result).to eq('standard_messages')
      end
    end

    context 'when model does not exist' do
      it 'falls back to convention-based inference' do
        result = helper.send(:table_name_for, 'NonExistentModel')
        expect(result).to eq('non_existent_models')
      end

      it 'handles namespaced non-existent models' do
        result = helper.send(:table_name_for, 'Foo::Bar::BazModel')
        expect(result).to eq('foo_bar_baz_models')
      end
    end
  end

  describe '#message_table_name' do
    context 'when Message model has custom table name' do
      before do
        model_class = Class.new do
          def self.table_name
            'chat_messages'
          end
        end
        stub_const('Message', model_class)
        helper.instance_variable_set(:@model_names, { message: 'Message' })
      end

      it 'returns the actual table name from the model' do
        result = helper.message_table_name
        expect(result).to eq('chat_messages')
      end
    end
  end
end
