require "log"
require "colorize"

class Logger
  LEVELS       = ["debug", "error", "fatal", "info", "warn"]
  SEVERITY_IDS = [0, 4, 5, 2, 3]
  COLORS       = [:light_cyan, :light_red, :red, :light_yellow, :light_magenta]

  getter raw_log = Log.for ""

  @@severity : Log::Severity = :info

  use_default

  def initialize
    @@severity = Logger.get_severity
    @backend = Log::IOBackend.new

    format_proc = ->(entry : Log::Entry, io : IO) do
      color = :default
      {% begin %}
        case entry.severity.label.to_s().downcase
          {% for lvl, i in LEVELS %}
          when {{lvl}}, "#{{{lvl}}}ing"
            color = COLORS[{{i}}]
          {% end %}
        else
        end
      {% end %}

      io << "[#{entry.severity.label}]".ljust(10).colorize(color)
      io << entry.timestamp.to_s("%Y/%m/%d %H:%M:%S") << " | "
      io << entry.message
    end

    @backend.formatter = Log::Formatter.new &format_proc

    Log.setup do |c|
      c.bind "*", @@severity, @backend
      c.bind "db.*", :error, @backend
      c.bind "duktape", :none, @backend
    end
  end

  def self.get_severity(level = "") : Log::Severity
    if level.empty?
      level = Config.current.log_level
    end
    {% begin %}
      case level.downcase
      when "off"
        return Log::Severity::None
        {% for lvl, i in LEVELS %}
          when {{lvl}}
          return Log::Severity.new SEVERITY_IDS[{{i}}]
        {% end %}
      else
        raise "Unknown log level #{level}"
      end
    {% end %}
  end

  # Ignores @@severity and always log msg
  def log(msg)
    @backend.write Log::Entry.new "", Log::Severity::None, msg,
      Log::Metadata.empty, nil
  end

  def self.log(msg)
    default.log msg
  end

  {% for lvl in LEVELS %}
    def {{lvl.id}}(msg)
      raw_log.{{lvl.id}} { msg }
    end
    def self.{{lvl.id}}(msg)
      default.not_nil!.{{lvl.id}} msg
    end
  {% end %}
end
