require "log"
require "colorize"

class Logger
  LEVELS       = ["debug", "error", "fatal", "info", "warn"]
  SEVERITY_IDS = [0, 4, 5, 2, 3]
  COLORS       = [:light_cyan, :light_red, :red, :light_yellow, :light_magenta]

  @@severity : Log::Severity = :info

  def initialize(level : String)
    {% begin %}
      case level.downcase
      when "off"
        @@severity = :none
        {% for lvl, i in LEVELS %}
        when {{lvl}}
          @@severity = Log::Severity.new SEVERITY_IDS[{{i}}]
        {% end %}
      else
        raise "Unknown log level #{level}"
      end
    {% end %}

    @log = Log.for("")

    @backend = Log::IOBackend.new
    @backend.formatter = ->(entry : Log::Entry, io : IO) do
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

    Log.builder.bind "*", @@severity, @backend
  end

  # Ignores @@severity and always log msg
  def log(msg)
    @backend.write Log::Entry.new "", Log::Severity::None, msg, nil
  end

  {% for lvl in LEVELS %}
    def {{lvl.id}}(msg)
      @log.{{lvl.id}} { msg }
    end
  {% end %}
end
