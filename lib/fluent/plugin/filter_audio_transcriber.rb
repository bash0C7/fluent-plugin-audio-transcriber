require 'fluent/plugin/filter'
require 'fluent/config/error'
require 'fileutils'
require_relative 'audio_transcriber/processor'

module Fluent
  module Plugin
    class AudioTranscriberFilter < Filter
      Fluent::Plugin.register_filter('audio_transcriber', self)

      # Configuration parameters
      desc 'MLX Whisper model name'
      config_param :model, :string, default: 'mlx-community/whisper-large-v3-turbo'

      desc 'Language code for transcription'
      config_param :language, :string, default: 'ja'

      desc 'Initial prompt to guide transcription'
      config_param :initial_prompt, :string, default: "これは日本語のビジネス会議や技術的な議論の文字起こしです。日本語特有の言い回し、敬語表現、専門用語、および固有名詞を正確に認識してください。あいまい表現や言いよどみは適切に処理し、カタカナ語や外来語も正確に変換してください。日本語として解釈できなかった場合は音の通りをカタカナで出力してください。「えー」「あの」などのフィラーは必要に応じて含めてください。"

      desc 'Input field name to audio content'
      config_param :input_content, :string, default: 'content'
      
      desc 'Output field name to store the transcription result'
      config_param :output_transcription, :string, default: 'transcription'

      def configure(conf)
        super
        @processor = AudioTranscriber::Processor.new(@model, @language, @initial_prompt)
      end

      def filter(tag, time, record)
        log.debug "#{self.class.name}\##{__method__} start" 
        # Process audio content and get transcription
        result = @processor.process(@content)
        
        # Remove original binary content to reduce record size
        record.delete(@content)
        
        # Add transcription and metadata to record
        record[@output_transcription] = result.join("\n")
        log.debug "#{self.class.name}\##{__method__} loop end" 
      
        record
      end
    end
  end
end