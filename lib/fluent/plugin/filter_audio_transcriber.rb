require 'fluent/plugin/filter'
require 'fluent/config/error'
require 'fileutils'
require_relative 'audio_transcriber/processor'

module Fluent
  module Plugin
    class AudioTranscriberFilter < Filter
      Fluent::Plugin.register_filter('audio_transcriber', self)

      # Processing options
      desc 'Transcode options (comma-separated key:value pairs for FFmpeg including filters)'
      config_param :transcode_options, :string, default: '-c:v copy -af loudnorm=I=-14:TP=0.0:print_format=summary'
      
      desc 'Output file extension'
      config_param :output_extension, :string, default: 'aac'
      
      # Other options
      desc 'Path for temporary files'
      config_param :buffer_path, :string, default: '/tmp/fluentd-audio-transcriber'

      # Output tag (default: "transcoded." + input tag)
      desc 'Output tag'
      config_param :tag, :string

      def configure(conf)
        super
        
        # Initialize processor
        @processor = AudioTranscriber::Processor.new(@transcode_options, @output_extension, @buffer_path)
      end

      def filter(tag, time, record)
        # Process the audio file
        result = @processor.process(record['path'], record['content'])

        # Use the actual transcoded file path
        record["path"] = result['path']
        # Use the size of the transcoded file
        record["size"] = result['size']
        # Include the transcoded binary content
        record["content"] = result['content']

        record
      end
    end
  end
end
