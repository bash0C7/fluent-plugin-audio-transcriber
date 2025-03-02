require 'fluent/plugin/filter'
require 'fluent/config/error'
require 'fileutils'
require_relative 'audio_transcriber/processor'

module Fluent
  module Plugin
    class AudioTranscriberFilter < Filter
      Fluent::Plugin.register_filter('audio_transcriber', self)

      # Processing options
      desc 'model'
      config_param :model, :string, default: 'mlx-community/whisper-large-v3-turbo'

      desc 'transcription language'
      config_param :language, :string, default: 'ja'

      desc 'initial prompt'
      config_param :initial_prompt, :string, default: "これは日本語のビジネス会議や技術的な議論の文字起こしです。日本語特有の言い回し、敬語表現、専門用語、および固有名詞を正確に認識してください。あいまい表現や言いよどみは適切に処理し、カタカナ語や外来語も正確に変換してください。日本語として解釈できなかった場合は音の通りをカタカナで出力してください。「えー」「あの」などのフィラーは必要に応じて含めてください。"

      def configure(conf)
        super
        
        # Initialize processor
        @processor = AudioTranscriber::Processor.new(@model, @language, @initial_prompt)
      end

      def filter(tag, time, record)
        # Process the audio file
        result = @processor.process(record['content'])

        # Remove the original binary content to reduce record size
        record.delete("content")
        
        # Add transcription and metadata
        record["transcription"] = result.join("\n")
        record["speech_recognition_model"] = @model
        record["transcription_language"] = @language
      
        record
      end
    end
  end
end
