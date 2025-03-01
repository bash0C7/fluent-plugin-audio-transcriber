#
# Copyright 2025- bash0C7
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'fluent/plugin/output'
require 'fluent/config/error'
require 'logger'
require 'pycall'
require 'pycall/import'
include PyCall::Import

module Fluent
  module Plugin
    class AudioTranscriberOutput < Output
      Fluent::Plugin.register_output('audio_transcriber', self)

      helpers :event_emitter

      desc 'タグ'
      config_param :tag, :string, default: 'audio.transcribed'

      desc '文字起こしモデル'
      config_param :model, :string, default: 'mlx-community/whisper-large-v3-turbo'

      desc '言語'
      config_param :language, :string, default: 'ja'

      desc '初期プロンプト'
      config_param :initial_prompt, :string, default: "これは日本語のビジネス会議や技術的な議論の文字起こしです。日本語特有の言い回し、敬語表現、専門用語、および固有名詞を正確に認識してください。あいまい表現や言いよどみは適切に処理し、カタカナ語や外来語も正確に変換してください。日本語として解釈できなかった場合は音の通りをカタカナで出力してください。「えー」「あの」などのフィラーは必要に応じて含めてください。"

      desc 'Python仮想環境のパス'
      config_param :python_venv_path, :string, default: './myenv'
      
      desc '文字起こし後に音声ファイルを削除するか'
      config_param :remove_audio, :bool, default: false
      
      desc '文字起こし結果に日時を追加するか'
      config_param :append_timestamp, :bool, default: true

      def configure(conf)
        super
        # Python環境の設定
        setup_python_environment
      end

      def start
        super
        @logger = create_logger
      end
      
      def process(tag, es)
        es.each do |time, record|
          begin
            audio_path = record['path']
            unless audio_path && File.exist?(audio_path)
              log.error "オーディオファイルが存在しません: #{audio_path}"
              next
            end

            # 文字起こし実行
            transcription_result, processing_time, segments_count = transcribe_audio(audio_path)
            
            if transcription_result
              # 新しいレコードを作成して転送
              new_record = record.merge(
                'transcription' => transcription_result,
                'model' => @model,
                'language' => @language,
                'processing_time' => processing_time,
                'segments_count' => segments_count
              )
              
              router.emit(@tag, time, new_record)
              log.info "文字起こしが完了しました: #{audio_path} (処理時間: #{processing_time.round(2)}秒, セグメント数: #{segments_count})"
              
              # 音声ファイルを削除（設定されている場合）
              if @remove_audio && File.exist?(audio_path)
                File.unlink(audio_path)
                log.info "音声ファイルを削除しました: #{audio_path}"
                
                # 元の録音ファイルも削除（存在する場合）
                if record['original_path'] && File.exist?(record['original_path'])
                  File.unlink(record['original_path'])
                  log.info "元の録音ファイルも削除しました: #{record['original_path']}"
                end
              end
            else
              log.error "文字起こしに失敗しました: #{audio_path}"
            end
          rescue => e
            log.error "文字起こし中にエラーが発生しました: #{e.class} #{e.message}"
            log.error_backtrace(e.backtrace)
          end
        end
      end

      private
      
      def create_logger
        logger = Logger.new(STDERR)
        logger.formatter = proc { |severity, datetime, progname, msg| 
          "#{datetime.strftime('%Y-%m-%d %H:%M:%S')} [#{severity}] AudioTranscriber: #{msg}\n" 
        }
        logger
      end
      
      def setup_python_environment
        log.info "Python環境を設定中..."
        
        # 仮想環境のパスの特定
        myenv_path = File.expand_path(@python_venv_path)
        unless Dir.exist?(myenv_path)
          raise Fluent::ConfigError, "Python仮想環境のパスが見つかりません: #{myenv_path}"
        end
        
        # Pythonのsite-packages検索
        site_packages_pattern = File.join(myenv_path, '**/site-packages')
        site_packages_path = Dir.glob(site_packages_pattern).first
        unless site_packages_path
          raise Fluent::ConfigError, "Pythonのsite-packagesディレクトリが見つかりません"
        end
        
        # サイトディレクトリを追加
        site = PyCall.import_module('site')
        site.addsitedir(site_packages_path)
        
        # 文字起こしモジュールをインポート
        begin
          pyimport :mlx_whisper
          log.info "MLX Whisperモジュールを正常にインポートしました"
        rescue => e
          raise Fluent::ConfigError, "MLX Whisperモジュールのインポートに失敗しました: #{e.message}"
        end
      end

      def transcribe_audio(audio_path)
        audio_basename = File.basename(audio_path)
        log.info "文字起こし開始: #{audio_basename} (モデル: #{@model}, 言語: #{@language})"
        
        start_time = Time.now
        
        begin
          # Whisperによる文字起こし実行
          result = run_whisper_transcription(audio_path)
          
          processing_time = Time.now - start_time
          
          # セグメントを抽出
          segments = result['segments']
          segments_count = segments.length
          log.info "セグメント数: #{segments_count}"
          
          # 結果を整形
          formatted_result = format_transcription_result(segments, audio_basename)
          
          return [formatted_result, processing_time, segments_count]
        rescue => e
          log.error "文字起こし処理エラー: #{e.message}"
          log.error_backtrace(e.backtrace)
          return [nil, 0, 0]
        end
      end
      
      def run_whisper_transcription(audio_file)
        # Whisperによる文字起こし実行
        mlx_whisper.transcribe(
          audio_file,
          path_or_hf_repo: @model,
          language: @language,
          fp16: true,
          temperature: [0.0, 0.2, 0.4, 0.6, 0.8],
          condition_on_previous_text: true,
          verbose: false,
          initial_prompt: @initial_prompt
        )
      end
      
      def format_transcription_result(segments, audio_basename)
        result = []
        
        # タイムスタンプを追加（設定されている場合）
        if @append_timestamp
          result << "=== 文字起こし結果: #{audio_basename} - #{Time.now.strftime('%Y-%m-%d %H:%M:%S')} ==="
          result << "=== 使用モデル: #{@model} ==="
        end
        
        # セグメントからテキストを抽出
        segments.each do |segment|
          text = segment['text'].strip
          result << text
        end
        
        if @append_timestamp
          result << "=== 文字起こし終了: #{audio_basename} ==="
        end
        
        result.join("\n")
      end
    end
  end
end
