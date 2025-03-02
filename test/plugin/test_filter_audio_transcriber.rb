require "helper"
require "fluent/plugin/filter_audio_transcriber.rb"
require "fileutils"
require "tempfile"
require "digest"


class AudioTranscriberActualTest < Test::Unit::TestCase
  setup do
    Fluent::Test.setup
    
    # Check prerequisites
    @is_macos = (`uname -s`).strip == "Darwin"
    
    # Check Python virtual environment
    @myenv_path = File.join(Dir.pwd, "myenv")
    @has_python_env = Dir.exist?(@myenv_path) && File.exist?(File.join(@myenv_path, "bin", "python"))
    
    # Only set up test environment if prerequisites are met
    if @is_macos && @has_python_env
      # Create temporary directory for test files
      @temp_dir = File.join(Dir.tmpdir, "fluent-plugin-audio-transcriber-test-#{rand(10000)}")
      FileUtils.mkdir_p(@temp_dir)
      
      # Generate test audio file using macOS say command
      @audio_file_path = File.join(@temp_dir, "hello.aiff")
      status = system("say", "-o", @audio_file_path, "hello")
      
      if status && File.exist?(@audio_file_path)
        # Read the audio content
        @test_audio_content = File.binread(@audio_file_path)
      else
        @test_audio_content = nil
        puts "Failed to create test audio file"
      end
    end
  end
  
  teardown do
    # Clean up temporary directory
    FileUtils.rm_rf(@temp_dir) if @is_macos && @has_python_env && Dir.exist?(@temp_dir)
  end

  # Configuration for actual transcription test
  ACTUAL_CONFIG = %[
    model mlx-community/whisper-large-v3-turbo
    language en
    initial_prompt You will be given the audio "hello", so please transcribe it as "hello"
  ]
  
  DEFAULT_TAG = "test.audio"
  
  sub_test_case "actual transcription" do
    test "transcribe hello audio to text" do
      # Fail test if prerequisites are not met
      flunk "This test requires macOS" unless @is_macos
      flunk "Python virtual environment not found" unless @has_python_env
      flunk "Failed to create test audio file" if @test_audio_content.nil?
      
      # MLX Whisper is assumed to be installed
      # If not, the test will fail with an error during execution
      
      # Create test message with actual audio content
      message = {
        "path" => @audio_file_path,
        "content" => @test_audio_content,
        "additional_field" => "value"
      }
      
      # Process the message with actual transcription
      filtered_records = filter(ACTUAL_CONFIG, [message])
      
      # Verify that the record was processed
      assert_equal 1, filtered_records.size
      
      record = filtered_records.first
      
      # Check that the content has been removed
      assert_nil record["content"], "Content field should be removed after processing"
      
      # Check that original fields are preserved
      assert_equal @audio_file_path, record["path"]
      assert_equal "value", record["additional_field"]
      
      # Check transcription (case insensitive)
      transcription = record["transcription"].to_s.downcase
      assert_include transcription, "hello", 
        "Transcription should include 'hello', but got: #{record['transcription']}"
      
      # Check metadata
      assert_equal "mlx-community/whisper-large-v3-turbo", record["speech_recognition_model"]
      assert_equal "en", record["transcription_language"]
    end
  end

  private

  # Helper method to create filter driver and process messages
  def filter(config, messages, tag = DEFAULT_TAG)
    d = create_driver(config)
    d.run(default_tag: tag) do
      messages.each do |message|
        d.feed(message)
      end
    end
    d.filtered_records
  end

  def create_driver(conf)
    Fluent::Test::Driver::Filter.new(Fluent::Plugin::AudioTranscriberFilter).configure(conf)
  end
end