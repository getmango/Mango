require "./config"
require "logger"
require "colorize"

LEVELS = ["debug", "error", "fatal", "info", "warn"]
COLORS = [:light_cyan, :light_red, :red, :light_yellow, :light_magenta]

class MLogger
	def initialize(config : Config)
		@logger = Logger.new STDOUT

		@log_off = false
		log_level = config.log_level
		if log_level == "off"
			@log_off = true
			return
		end

		{% begin %}
			case log_level
				{% for lvl in LEVELS %}
				when {{lvl}}
					@logger.level = Logger::{{lvl.upcase.id}}
				{% end %}
			else
				raise "Unknown log level #{log_level}"
			end
		{% end %}

		@logger.formatter = Logger::Formatter.new do \
			|severity, datetime, progname, message, io|

			color = :default
			{% begin %}
				case severity.to_s().downcase
					{% for lvl, i in LEVELS %}
					when {{lvl}}
						color = COLORS[{{i}}]
					{% end %}
				end
			{% end %}

			io << "[#{severity}]".ljust(8).colorize(color)
			io << datetime.to_s("%Y/%m/%d %H:%M:%S") << " | "
			io << message
		end
	end

	{% for lvl in LEVELS %}
		def {{lvl.id}}(msg)
			return if @log_off
			@logger.{{lvl.id}} msg
		end
	{% end %}
end
