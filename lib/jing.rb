require "optout"

class Jing
  VERSION = "0.0.3"
  DEFAULT_JAR = File.join(File.dirname(__FILE__), "jing-20091111.jar")

  Error = Class.new(StandardError)
  ExecutionError = Class.new(Error)
  OptionError = Class.new(Error)

  @@option_builder = Optout.options do
    on :java,     :required => true, :default => "java"
    on :java_opts,        String
    on :jar,      "-jar", Optout::File.exists, :default => DEFAULT_JAR
    on :compact,  "-c",   Optout::Boolean
    on :encoding, "-e",   String
    on :id_check, "-i",   Optout::Boolean,     :default  => false
    on :schema,           Optout::File.exists, :required => true
    on :xmlfile,          Optout::File.exists, :required => true
  end

  ##
  # Cretae an instance to validate against the given schema. The schema can be in the XML or compact syntax.
  #
  #  jing = Jing.new("schema.rng", options)
  #
  # === Arguments
  #
  # [schema (String)] Path to the schema
  # [options (Hash)] Jing options, optional
  #
  # === Options
  #
  # [:java (String)] Name and/or location of the java executable. Defaults to <code>"java"</code>.
  # [:jar (String)] Path to the Jing JAR file. Defaults to the bundled JAR.
  # [:compact (Boolean)] Set to +true+ if the schema uses the RELAX NG compact syntax. Defaults to false, will be set to +true+ is the schema has a +.rnc+ extension.
  # [:encoding (String)] Encoding of the XML document.
  # [:id_check (Boolean)] Disable checking of ID/IDREF/IDREFS. Defaults to +false+
  #
  # === Errors
  #
  # [ArgumentError] If the options are not +nil+ or a +Hash+.

  def initialize(schema, options = nil)
    if options
      raise ArgumentError, "options must be a Hash" unless Hash === options
      @options = options.dup
    end

    @options ||= {}
    @options[:schema] = schema
    @options[:compact] = true if @options[:compact].nil? and @options[:schema] =~ /\.rnc\Z/i   # Don't override an explicit setting
    # Optout quirk: true will *include* the switch, which means we *don't* want to check
    @options[:id_check] = !@options[:id_check] if @options.include?(:id_check)
    if @options[:encoding]
      @options[:java_opts] = "-Dfile.encoding=#{@options[:encoding]}"
    end
  end

  ##
  # Validate an XML document against the schema.
  #
  #  errors = jing.validate("doc.xml")
  #
  # === Arguments
  #
  # [xml (String)] Path to the XML file
  #
  # === Errors
  #
  # [Jing::OptionError] A Jing option was invalid. Note that this <b>does not apply to an invalid <code>:java</code> option.</b>
  # [Jing::ExecutionError] Problems were encountered trying to execute Jing.
  #
  # === Returns
  #
  # [Array] The errors, each element is a +Hash+. See Error Hash for more info.
  #
  # ==== Error Hash
  #
  # The error hash contains the following keys/values
  #
  # [:source (String)] File containing the error, can be the schema or the instance XML.
  # [:line (Fixnum)] Line number
  # [:column (Fixnum)] Column number
  # [:message (String)] The problem

  def validate(xml)
    @options[:xmlfile] = xml

    out = execute(@options)
    return [] if $?.success? and out.empty?

    parse_output(out)
  end

  # Validate an XML document against the schema. To receive a list of validation errors use #validate.
  #
  #  puts "yay!" if jing.valid?("doc.xml")
  #
  # === Arguments
  #
  # [xml (String)] Path to the XML file
  #
  # === Errors
  #
  # Same as #validate
  #
  # === Returns
  #
  # [Boolean] +true+ if valid, +false+ if invalid
  #

  def valid?(xml)
    errors = validate(xml)
    errors.none?
  end

  private
  def execute(options)
    cmd = @@option_builder.shell(options)
    `#{cmd} 2>&1`
  rescue SystemCallError => e
    raise ExecutionError, "jing execution failed: #{e}"
  rescue Optout::OptionError => e
    raise OptionError, e.message
  end

  def parse_output(output)
    errors = []
    output.split("\n").each do |line|
      case line
      when /\A(.+):(\d+):(\d+):\s+\w+:\s+(.+)\Z/
        errors << {
          :source  => $1,
          :line    => $2.to_i,
          :column  => $3.to_i,
          :message => $4
        }
      when /Picked up _JAVA_OPTIONS: /
        # ignore diagnostic message
      else # There must have been a problem that was not schema related
        raise ExecutionError, output
      end
    end
    errors
  rescue ArgumentError => e
    raise ExecutionError, "potentially wrong encoding of jing output." \
      "try setting the file's encoding via the :encoding option: #{e}"
  end
end
