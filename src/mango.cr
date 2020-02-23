require "./server"
require "./context"
require "option_parser"

VERSION = "0.1.0"

config_path = nil

parser = OptionParser.parse do |parser|
	parser.banner = "Mango e-manga server/reader. Version #{VERSION}\n"

	parser.on "-v", "--version", "Show version" do
		puts "Version #{VERSION}"
		exit
	end
	parser.on "-h", "--help", "Show help" do
		puts parser
		exit
	end
	parser.on "-c PATH", "--config=PATH", "Path to the config file. " \
		"Default is `~/.config/mango/config.yml`" do |path|
		config_path = path
	end
end

config = Config.load config_path
logger = MLogger.new config
storage = Storage.new config.db_path, logger
library = Library.new config.library_path, config.scan_interval, logger, storage

context = Context.new config, logger, library, storage

server = Server.new context
server.start
