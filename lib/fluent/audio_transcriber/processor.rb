require 'pycall'
require 'pycall/import'
include PyCall::Import

module Fluent
  module Plugin
    module AudioTranscriber
      class Processor
        def initialize(model)
          @model = model 

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
        
        def process(audio_file)
          transcribed = run_whisper_transcription(audio_file, @model)
          transcribed['segments'].map { |segment| segment['text'].strip}
        end
      end
    end
  end
end
