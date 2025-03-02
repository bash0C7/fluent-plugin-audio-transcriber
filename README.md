# fluent-plugin-audio-transcriber

[Fluentd](https://fluentd.org/) filter plugin for transcribing audio files using MLX Whisper.

## Overview

This filter plugin transcribes audio content using MLX Whisper and adds the transcription text to the record.

**Note**: This plugin is designed to work only on macOS as it relies on MLX, which is optimized for Apple Silicon.

## Installation

### RubyGems

```
$ gem install fluent-plugin-audio-transcriber
```

### Bundler

Add the following line to your Gemfile:

```ruby
gem "fluent-plugin-audio-transcriber"
```

And then execute:

```
$ bundle
```

## Prerequisites

- macOS (the plugin uses MLX which is optimized for Apple Silicon)
- Ruby 3.4 or higher
- Fluentd v1.0.0 or higher
- Python 3.11 or higher
- MLX Whisper installed in a Python environment

## Python Environment Setup

You need to set up a Python virtual environment with MLX Whisper installed:

```bash
# Install Python using pyenv on macOS
brew install pyenv
pyenv init
pyenv install 3.11
pyenv rehash
pyenv local 3.11

# Create Python virtual environment and install required packages
# Note: The virtual environment must be created in the same directory as your Fluentd configuration
python -m venv myenv
source myenv/bin/activate
pip install mlx-whisper
```

## Configuration

```
<filter audio.raw>
  @type audio_transcriber
  
  # MLX Whisper settings
  model mlx-community/whisper-large-v3-turbo  # Transcription model
  language ja                                  # Language code
  initial_prompt This is a transcription of Japanese business meetings and technical discussions. Please accurately recognize Japanese expressions, honorific language, technical terms, and proper nouns.
</filter>
```

### Plugin Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| model | string | MLX Whisper model name | mlx-community/whisper-large-v3-turbo |
| language | string | Language code for transcription | ja |
| initial_prompt | string | Initial prompt to guide transcription | A detailed Japanese prompt (see source code) |

## Input Record Format

The plugin expects records with the following field:

```
{
  "content": <binary data of audio file>,
  ... (other fields)
}
```

## Output Record Format

The plugin processes the record and modifies it to:

```
{
  "transcription": "Transcribed text line 1\nTranscribed text line 2\n...",
  "speech_recognition_model": "mlx-community/whisper-large-v3-turbo",
  "transcription_language": "ja",
  ... (other original fields except 'content')
}
```

**Note**: The `content` field is removed from the output record to reduce data size.

## Common Issues

### PyCall Related Errors

Make sure the Python virtual environment (`myenv`) exists in the same directory where Fluentd is running.

## Development

After checking out the repo, run `bundle install` to install dependencies. Then, run `bundle exec rake test` to run the tests.

To release a new version, update the version number in the gemspec file, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/bash0C7/fluent-plugin-audio-transcriber.

## License

[Apache License, Version 2.0](LICENSE)
