# frozen_string_literal: true

module RubyLLM
  # Represents the content sent to or received from an LLM.
  # Selects the appropriate attachment class based on the content type.
  class Content
    attr_reader :text, :attachments, :input_files

    def initialize(text = nil, attachments = nil, input_files = nil)
      @text = text
      @attachments = []
      @input_files = input_files

      process_attachments(attachments)
      raise ArgumentError, 'Text and attachments or input files cannot be nil' if (@text.nil? && @attachments.empty?) || (@text.nil? && @input_files.empty?)
    end

    def add_attachment(source, filename: nil)
      @attachments << Attachment.new(source, filename:)
      self
    end

    def add_input_file(input_file)
      @input_files << input_file
      self
    end

    def format
      if @text && @attachments.empty? && @input_files.empty?
        @text
      else
        self
      end
    end

    # For Rails serialization
    def to_h
      { text: @text, attachments: @attachments.map(&:to_h), input_files: @input_files }
    end

    private

    def process_attachments_array_or_string(attachments)
      Utils.to_safe_array(attachments).each do |file|
        add_attachment(file)
      end
    end

    def process_attachments(attachments)
      if attachments.is_a?(Hash)
        # Ignores types (like :image, :audio, :text, :pdf) since we have robust MIME type detection
        attachments.each_value(&method(:process_attachments_array_or_string))
      else
        process_attachments_array_or_string attachments
      end
    end
  end
end
