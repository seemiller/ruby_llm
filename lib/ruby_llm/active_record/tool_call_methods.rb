# frozen_string_literal: true

module RubyLLM
  module ActiveRecord
    # Methods mixed into tool_call models.
    # This module exists primarily to provide a means to detect which models
    # are ToolCall models (via module inclusion checking).
    module ToolCallMethods
      extend ActiveSupport::Concern
    end
  end
end
