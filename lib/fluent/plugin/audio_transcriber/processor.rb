require 'pycall'
require 'pycall/import'
include PyCall::Import

module Fluent
  module Plugin
    module AudioTranscriber
      class Processor
        def initialize(model, language, initial_prompt)
          @model = model 
          @language = language
          @initial_prompt = initial_prompt

          # 仮想環境のパスの特定（シンプル化）
          myenv_path = File.join(Dir.pwd, "myenv")
          fail "仮想環境 'myenv' が見つかりません" unless Dir.exist?(myenv_path)
          
          # Pythonのsite-packages検索（より効率的に）
          site_packages_pattern = File.join(myenv_path, '**/site-packages')
          site_packages_path = Dir.glob(site_packages_pattern).first
          fail "Pythonのsite-packagesディレクトリが見つかりません" unless site_packages_path
          
          # サイトディレクトリを追加
          site = PyCall.import_module('site')
          site.addsitedir(site_packages_path)
          
          # 文字起こしモジュールをインポート
          pyimport 'mlx_whisper'          
        end
        
        def process(content)
          result = []

          Tempfile.create(self.to_s) do |f|
            File.binwrite(f.path, content)

            transcribed = mlx_whisper.transcribe(
              f.path,
              path_or_hf_repo: @model,
              language: "ja",
              fp16: true,
              temperature: [0.0, 0.2, 0.4, 0.6, 0.8],
              condition_on_previous_text: true,
              verbose: false,
              initial_prompt: @initial_promplt
            )
            result = transcribed['segments'].map { |segment| segment['text'].strip}

          end

          result
        end
      end
    end
  end
end
