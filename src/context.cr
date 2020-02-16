require "./config"
require "./library"
require "./storage"
require "./logger"

class Context
	property config : Config
	property library : Library
	property storage : Storage
	property logger : MLogger

	def initialize(@config, @logger, @library, @storage)
	end

	{% for lvl in LEVELS %}
		def {{lvl.id}}(msg)
			@logger.{{lvl.id}} msg
		end
	{% end %}
end
