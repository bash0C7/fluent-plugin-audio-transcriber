# fluent-plugin-audio-transcriber

[Fluentd](https://fluentd.org/) output plugin to do something.

TODO: write description for you plugin.

## Installation

### RubyGems

```
$ gem install fluent-plugin-audio-transcriber
```

### Bundler

Add following line to your Gemfile:

```ruby
gem "fluent-plugin-audio-transcriber"
```

And then execute:

```
$ bundle
```

## Configuration

You can generate configuration template:

```
$ fluent-plugin-config-format output audio-transcriber
```

You can copy and paste generated documents here.

## Copyright

* Copyright(c) 2025- bash0C7
* License
  * Apache License, Version 2.0

# fluent-plugin-audio-transcriber

Fluentd用の音声文字起こし出力プラグイン。MLX Whisperを使用して音声ファイルから文字起こしを行います。

## インストール

```
$ gem install fluent-plugin-audio-transcriber
```

## 設定

```
<match audio.normalized>
  @type audio_transcriber
  
  # MLX Whisper設定
  model mlx-community/whisper-large-v3-turbo  # 文字起こしモデル
  language ja                                 # 言語
  initial_prompt これは日本語のビジネス会議や技術的な議論の文字起こしです。日本語特有の言い回し、敬語表現、専門用語、および固有名詞を正確に認識してください。
  
  # Python環境設定
  python_venv_path /path/to/myenv             # Python仮想環境のパス（デフォルト: ./myenv）
  
  # 出力設定
  tag audio.transcribed                       # 次のステージへのタグ（デフォルト: audio.transcribed）
  remove_audio false                          # 文字起こし後に音声ファイルを削除するか（デフォルト: false）
  append_timestamp true                       # 文字起こし結果に日時を追加するか（デフォルト: true）
</match>
```

## 入力レコード形式

```
{
  "path": "/path/to/normalized/audio/file.normalized.aac",
  "content": "<binary>",
}
```

## 出力レコード形式

```
{
  "path": "/path/to/normalized/audio/file.normalized.aac",
  "transcription": "ここに文字起こし1行分が入ります...",
  "speech_recognition_model": "mlx-community/whisper-large-v3-turbo",
  "transcription_language": "ja",
}
```

## 必要条件

- Ruby 2.5.0以上
- fluentd v1.0.0以上
- Python 3.11以上
- MLX Whisper（Python環境にインストール済みであること）

## セットアップ手順

1. Python仮想環境の作成とMLX Whisperのインストール

```bash
# macOSでのpythonのインストール
brew install pyenv
pyenv init
pyenv install 3.11
pyenv rehash
pyenv versions
pyenv local 3.11

# Python仮想環境と必要パッケージのインストール
# 注意: 仮想環境はRakefileと同じディレクトリに作成する必要があります
pyenv exec python -m venv myenv
source myenv/bin/activate
pip install mlx-whisper

python -m venv myenv
source myenv/bin/activate
pip install mlx-whisper
```

2. fluentdプラグインのインストール

```bash
gem install fluent-plugin-audio-transcriber
```

## よくある問題と解決方法

### PyCall関連のエラー

Python仮想環境のパスが正しく設定されていることを確認してください。

```
python_venv_path /path/to/your/python/venv
```

## ライセンス

MIT License
