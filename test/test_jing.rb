require "minitest/autorun"
require "tempfile"
require "jing"

class TestJing < MiniTest::Unit::TestCase
  root = File.join(File.expand_path(File.dirname(__FILE__)), "fixtures")

  VALID_XML = File.join(root, "valid.xml")
  INVALID_XML = File.join(root, "invalid.xml")
  RNG_SCHEMA = File.join(root, "schema.rng")
  RNC_SCHEMA = File.join(root, "schema.rnc")

  def test_default_jar_file_used
    cmd = fakeshell { Jing.new(RNG_SCHEMA).validate(VALID_XML) }
    assert_match /\A'java'\s+ -jar\s+ '#{Jing::DEFAULT_JAR}' \s+/x, cmd
  end

  def test_jar_file_must_exist
    assert_raises Jing::OptionError, /\bjar\b/ do
      Jing.new(RNG_SCHEMA, :jar => "__oopsy__!").validate(VALID_XML)
    end
  end

  def test_jar_option
    jar = Tempfile.new "jar"
    cmd = fakeshell { Jing.new(RNG_SCHEMA, :jar => jar.path).validate(VALID_XML) }
    assert_match /\A'java'\s+ -jar\s+ '#{jar.path}' \s+/x, cmd
  end

  def test_java_option
    java = "/usr/alt/java"
    cmd = fakeshell { Jing.new(RNG_SCHEMA, :java => java).validate(VALID_XML) }
    assert_match /\A'#{java}'\s+/, cmd
  end

  def test_java_must_exist
    # This should be an OptionError!
    assert_raises Jing::ExecutionError, /\bjava\b/ do
      Jing.new(RNG_SCHEMA, :java => "__no_no_no__").validate(VALID_XML)
    end
  end

  def test_encoding_option
    enc = "iso-8859-1"
    cmd = fakeshell { Jing.new(RNG_SCHEMA, :encoding => enc).validate(VALID_XML) }
    assert_match /\A'java'\s+ '-Dfile.encoding=#{enc}'\s+ -jar\s+ '#{Jing::DEFAULT_JAR}'\s+ -e\s+ '#{enc}'/x, cmd
  end

  def test_id_check_option
    cmd = fakeshell { Jing.new(RNG_SCHEMA, :id_check => false).validate(VALID_XML) }
    assert_match /\A'java'\s -jar\s+ '#{Jing::DEFAULT_JAR}'\s+ -i/x, cmd

    cmd = fakeshell { Jing.new(RNG_SCHEMA, :id_check => true).validate(VALID_XML) }
    refute_match /\b-i\b/x, cmd

    cmd = fakeshell { Jing.new(RNG_SCHEMA).validate(VALID_XML) }
    refute_match /\b-i\b/x, cmd
  end

  def test_compact_option
    cmd = fakeshell { Jing.new(RNC_SCHEMA, :compact => true).validate(VALID_XML) }
    assert_match /\A'java'\s -jar\s+ '#{Jing::DEFAULT_JAR}'\s+ -c/x, cmd

    cmd = fakeshell { Jing.new(RNC_SCHEMA, :compact => false).validate(VALID_XML) }
    refute_match /\b-c\b/, cmd
  end

  def test_compact_option_when_compact_schema_is_used
    cmd = fakeshell { Jing.new(RNC_SCHEMA).validate(VALID_XML) }
    assert_match /\A'java'\s+ -jar\s+ '#{Jing::DEFAULT_JAR}'\s+ -c/x, cmd
  end

  def test_relaxng_file_must_exist
    assert_raises Jing::OptionError, /cannot read/ do
      Jing.new("bad_file_name").validate(VALID_XML)
    end
  end

  def test_instance_xml_file_must_exist
    assert_raises Jing::OptionError, /cannot read/ do
      Jing.new(VALID_XML).validate("bad_file_name")
    end
  end

  def test_valid_instance_xml_returns_true
    assert Jing.new(RNG_SCHEMA).valid?(VALID_XML)
  end

  def test_valid_instance_xml_returns_no_errors
    errors = Jing.new(RNG_SCHEMA).validate(VALID_XML)
    assert_equal 0, errors.size    
  end

  def test_invalid_instance_xml_returns_false
    assert !Jing.new(RNG_SCHEMA).valid?(INVALID_XML)
  end

  def test_invalid_instance_xml_returns_errors
    errors = Jing.new(RNG_SCHEMA).validate(INVALID_XML)
    assert_equal 1, errors.size

    err = errors[0]
    assert_equal INVALID_XML, Pathname.new(err[:source]).cleanpath.to_s
    assert_equal 4, err[:line]
    assert_match /\A\d\d?\z/, err[:column].to_s
    assert_match /\bemail\b/, err[:message]
  end

  def test_successful_exit_status_with_unparsable_output_raises_an_exception
    output = "something bad happened"
    assert_raises Jing::ExecutionError, /#{output}/ do
      fakeshell(:exit => 0, :output => output) { Jing.new(RNG_SCHEMA).validate(VALID_XML) }
    end
  end

  def test_java_options_env_diagnostic_message
    output = "Picked up _JAVA_OPTIONS: -Djava.io.tmpdir=/tmp"
    fakeshell(:exit => 0, :output => output) {
      errors = Jing.new(RNG_SCHEMA).validate(VALID_XML)
      assert_equal 0, errors.size
    }
  end

  private
  def fakeshell(options = {})
    output = options.delete(:output) || ""
    exit_code = options.delete(:exit) || 0

    cmd = nil
    Object.class_eval do
      alias_method "real_tick", "`"
      define_method("`") do |arg|
        cmd = arg
        real_tick %{ruby -e"exit #{exit_code}"} # Just to set $?
        output
      end
    end

    yield
    cmd.tr %{"}, %{'}  # replace Win quotes with *nix
  ensure
    Object.class_eval do
      undef_method "`" #`
      alias_method "`", "real_tick"
      undef_method "real_tick"
    end
  end
end
