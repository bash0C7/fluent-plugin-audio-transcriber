require "helper"
require "fluent/plugin/filter_audio_transcriber.rb"
require "fileutils"
require "tempfile"
require "digest"

class AudioTranscriberFilterTest < Test::Unit::TestCase
  setup do
    Fluent::Test.setup
    
    # Create temporary directory for test files
    @temp_dir = File.join(Dir.tmpdir, "fluent-plugin-audio-transcriber-test-#{rand(10000)}")
    FileUtils.mkdir_p(@temp_dir)
    
    # Create a test audio content (mock binary data)
    @test_audio_content = "MOCK_AUDIO_BINARY_DATA"
    
    # Mock the processor
    setup_processor_mock
  end
  
  teardown do
    # Clean up temporary directory
    FileUtils.rm_rf(@temp_dir) if Dir.exist?(@temp_dir)
  end

  DEFAULT_CONFIG = %[
    model test-model
    language en
    initial_prompt This is a test prompt
  ]
  
  DEFAULT_TAG = "test.audio"
  
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
  
  # Mock the processor class to avoid actual MLX Whisper calls
  def setup_processor_mock
    # Create a mock processor class
    mock_processor_class = Class.new do
      def initialize(model, language, initial_prompt)
        @model = model
        @language = language
        @initial_prompt = initial_prompt
      end
      
      def process(content)
        # Return mock transcription results
        ["This is a test transcription", "Second line of transcription"]
      end
    end
    
    # Replace the actual processor with our mock
    original_processor = Fluent::Plugin::AudioTranscriber::Processor
    stub(Fluent::Plugin::AudioTranscriber).const_get(:Processor) { mock_processor_class }
  end
  
  sub_test_case "configuration" do
    test "default configuration" do
      d = create_driver(DEFAULT_CONFIG)
      assert_equal 'test-model', d.instance.model
      assert_equal 'en', d.instance.language
      assert_equal 'This is a test prompt', d.instance.initial_prompt
    end
    
    test "custom configuration" do
      custom_config = %[
        model custom-model
        language ja
        initial_prompt Custom prompt
      ]
      
      d = create_driver(custom_config)
      assert_equal 'custom-model', d.instance.model
      assert_equal 'ja', d.instance.language
      assert_equal 'Custom prompt', d.instance.initial_prompt
    end
  end
  
  sub_test_case "filter processing" do
    test "transcription process" do
      # Create test message with audio content
      message = {
        "path" => "/path/to/audio.mp3",
        "content" => @test_audio_content,
        "additional_field" => "value"
      }
      
      # Process the message
      filtered_records = filter(DEFAULT_CONFIG, [message])
      
      # Verify that the record was processed
      assert_equal 1, filtered_records.size
      
      record = filtered_records.first
      
      # Check that the content has been removed
      assert_nil record["content"]
      
      # Check that original fields are preserved
      assert_equal "/path/to/audio.mp3", record["path"]
      assert_equal "value", record["additional_field"]
      
      # Check that transcription and metadata have been added
      assert_equal "This is a test transcription\nSecond line of transcription", record["transcription"]
      assert_equal "test-model", record["speech_recognition_model"]
      assert_equal "en", record["transcription_language"]
    end
  end

  private

  def create_driver(conf = DEFAULT_CONFIG)
    Fluent::Test::Driver::Filter.new(Fluent::Plugin::AudioTranscriberFilter).configure(conf)
  end
end
