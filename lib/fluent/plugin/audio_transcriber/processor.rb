require 'pycall'
require 'pycall/import'
require 'tempfile'
include PyCall::Import

module Fluent
  module Plugin
    module AudioTranscriber
      class Processor
        def initialize(model, language, initial_prompt)
          @model = model 
          @language = language
          @initial_prompt = initial_prompt

          # Find Python virtual environment
          myenv_path = File.join(Dir.pwd, 'myenv')
          fail 'Virtual environment "myenv" not found' unless Dir.exist?(myenv_path)
          
          # Find site-packages directory
          site_packages_pattern = File.join(myenv_path, '**/site-packages')
          site_packages_path = Dir.glob(site_packages_pattern).first
          fail 'Python site-packages directory not found' unless site_packages_path
          
          # Setup Python environment
          site = PyCall.import_module('site')
          site.addsitedir(site_packages_path)
          pyimport 'mlx_whisper'
        end
        
        def process(content)
          Tempfile.create('audio_file') do |f|
            File.binwrite(f.path, content)
            
            # Transcribe audio using MLX Whisper
            transcribed = mlx_whisper.transcribe(
              f.path,
              path_or_hf_repo: @model,
              language: @language,
              fp16: true,
              temperature: [0.0, 0.2, 0.4, 0.6, 0.8],
              condition_on_previous_text: true,
              verbose: false,
              initial_prompt: @initial_prompt
            )
            
            # Extract and clean text segments
            transcribed['segments'].map { |segment| segment['text'].strip }
          end
        end
      end
    end
  end
end
