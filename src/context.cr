require "./config"
require "./library"
require "./storage"
require "logger"

class Context
	property config : Config
	property library : Library
	property storage : Storage

	def initialize
		@config = Config.load
		@library = Library.new @config.library_path, @config.scan_interval
		@storage = Storage.new @config.db_path
	end

end
