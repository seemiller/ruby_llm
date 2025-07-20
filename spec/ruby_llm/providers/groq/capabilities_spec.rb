# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RubyLLM::Providers::Groq::Capabilities do
  describe '.normalize_temperature' do
    it 'preserves temperature for all models' do
      models = %w[llama3-8b llama3-70b mixtral-8x7b gemma-7b gemma-2b]

      models.each do |model|
        result = described_class.normalize_temperature(0.7, model)
        expect(result).to eq(0.7)
      end
    end
  end

  describe '.model_family' do
    it 'correctly identifies llama3-8b models' do
      expect(described_class.model_family('llama3-8b')).to eq('llama3_8b')
    end

    it 'correctly identifies llama3-8b instrucr models' do
      expect(described_class.model_family('llama3-8b-instruct')).to eq('llama3_8b')
    end

    it 'correctly identifies llama3-70b models' do
      expect(described_class.model_family('llama3-70b')).to eq('llama3_70b')
    end

    it 'correctly identifies llama3-70b instruct models' do
      expect(described_class.model_family('llama3-70b-instruct')).to eq('llama3_70b')
    end

    it 'correctly identifies mixtral-8x7b models' do
      expect(described_class.model_family('mixtral-8x7b')).to eq('mixtral_8x7b')
    end

    it 'correctly identifies mixtral-8x7b instruct models' do
      expect(described_class.model_family('mixtral-8x7b-instruct')).to eq('mixtral_8x7b')
    end

    it 'correctly identifies gemma 7b models' do
      expect(described_class.model_family('gemma-7b')).to eq('gemma_7b')
    end

    it 'correctly identifies gemma 2b models' do
      expect(described_class.model_family('gemma-2b')).to eq('gemma_2b')
    end

    it 'returns "other" for unknown models' do
      expect(described_class.model_family('unknown-model')).to eq('other')
    end
  end
end