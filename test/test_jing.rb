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
    cmd = fakeshell { Jing.new.validate(RNG_SCHEMA, VALID_XML) }
    assert_match /\A'java'\s+ -jar\s+ '#{Jing::DEFAULT_JAR}' \s+/x, cmd
  end

  def test_jar_file_must_exist
    assert_raises Jing::OptionError, /\bjar\b/ do
      Jing.new(:jar => "__oopsy__!").validate(RNG_SCHEMA, VALID_XML)
    end
  end

  def test_jar_option
    jar = Tempfile.new "jar"
    cmd = fakeshell { Jing.new(:jar => jar.path).validate(RNG_SCHEMA, VALID_XML) }
    assert_match /\A'java'\s+ -jar\s+ '#{jar.path}' \s+/x, cmd
  end

  def test_java_option
    java = "/usr/alt/java"
    cmd = fakeshell { Jing.new(:java => java).validate(RNG_SCHEMA, VALID_XML) }
    assert_match /\A'#{java}'\s+/, cmd
  end

  def test_java_must_exist
    # This should be an OptionError!
    assert_raises Jing::ExecutionError, /\bjava\b/ do
      Jing.new(:java => "__no_no_no__").validate(RNG_SCHEMA, VALID_XML)
    end
  end

  def test_encoding_option
    enc = "iso-8859-1"
    cmd = fakeshell { Jing.new(:encoding => enc).validate(RNG_SCHEMA, VALID_XML) }
    assert_match /\A'java'\s+ -jar\s+ '#{Jing::DEFAULT_JAR}'\s+ -e\s+ '#{enc}'/x, cmd
  end

  def test_id_check_option
    cmd = fakeshell { Jing.new(:id_check => false).validate(RNG_SCHEMA, VALID_XML) }
    assert_match /\A'java'\s -jar\s+ '#{Jing::DEFAULT_JAR}'\s+ -i/x, cmd

    cmd = fakeshell { Jing.new(:id_check => true).validate(RNG_SCHEMA, VALID_XML) }
    refute_match /\b-i\b/x, cmd

    cmd = fakeshell { Jing.new.validate(RNG_SCHEMA, VALID_XML) }
    refute_match /\b-i\b/x, cmd
  end

  def test_compact_option
    cmd = fakeshell { Jing.new(:compact => true).validate(RNC_SCHEMA, VALID_XML) }
    assert_match /\A'java'\s -jar\s+ '#{Jing::DEFAULT_JAR}'\s+ -c/x, cmd

    cmd = fakeshell { Jing.new(:compact => false).validate(RNC_SCHEMA, VALID_XML) }
    refute_match /\b-c\b/, cmd
  end

  def test_compact_option_when_compact_schema_is_used
    cmd = fakeshell { Jing.new.validate(RNC_SCHEMA, VALID_XML) }
    assert_match /\A'java'\s+ -jar\s+ '#{Jing::DEFAULT_JAR}'\s+ -c/x, cmd
  end

  def test_relaxng_file_must_exist
    assert_raises Jing::OptionError, /cannot read/ do
      Jing.new.validate("bad_file_name", VALID_XML)
    end
  end

  def test_instance_xml_file_must_exist
    assert_raises Jing::OptionError, /cannot read/ do
      Jing.new.validate(VALID_XML, "bad_file_name")
    end
  end

  def test_valid_instance_xml_returns_no_errors
    errors = Jing.new.validate(RNG_SCHEMA, VALID_XML)
    assert_equal 0, errors.size
  end

  def test_invalid_instance_xml_errors_are_parsed
    errors = Jing.new.validate(RNG_SCHEMA, INVALID_XML)
    assert_equal 1, errors.size

    err = errors[0]
    assert_equal INVALID_XML, err[:file]
    assert_equal 4, err[:line]
    assert_match /\A\d\d?\z/, err[:column].to_s
    assert_match /\bemail\b/, err[:message]
  end

  def test_successful_command_with_un_parsable_output_raises_an_exception
    output = "something bad happened"
    assert_raises Jing::ExecutionError, /#{output}/ do
      fakeshell(:exit => 0, :output => output) { Jing.new.validate(RNC_SCHEMA, VALID_XML) }
    end
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
