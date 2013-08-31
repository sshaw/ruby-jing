require "optout"

class Jing
  DEFAULT_JAR = File.join(File.dirname(__FILE__), "jing-20091111.jar")

  Error = Class.new(StandardError)
  ExecutionError = Class.new(Error)
  OptionError = Class.new(Error)

  @@option_builder = Optout.options do
    on :java,     :required => true, :default => "java"
    on :jar,      "-jar", Optout::File.exists, :default => DEFAULT_JAR
    on :compact,  "-c",   Optout::Boolean
    on :encoding, "-e",   String
    on :id_check, "-i",   Optout::Boolean,     :default  => false
    on :rngfile,          Optout::File.exists, :required => true
    on :xmlfile,          Optout::File.exists, :required => true
  end

  def initialize(options = nil)
    if options
      raise ArgumentError, "options must be a Hash" unless Hash === options
      @options = options.dup
    end

    @options ||= {}
  end

  def validate(rng, xml)
    @options[:compact] = true if @options[:compact].nil? and rng =~ /\.rnc\Z/i   # Don't override an explicit setting
    @options[:rngfile] = rng
    @options[:xmlfile] = xml

    out = execute(@options)
    return [] if $?.success? and out.empty?
    errors = parse_output(out)
    raise ExecutionError, out if errors.none? # There must have been a problem that was not schema related
    errors
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
    output.split("\n").map do |line|
      if line =~ /\A(.+):(\d+):(\d+):\s+\w+:\s+(.+)\Z/
        errors << {
          :file   => $1,
          :line   => $2.to_i,
          :column => $3.to_i,
          :error  => $4
        }
      end
    end
    errors
  end
end
