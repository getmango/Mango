require "./server"
require "./context"
require "./config"
require "./library"
require "./storage"
require "./logger"

config = Config.load
logger = MLogger.new config
library = Library.new config.library_path, config.scan_interval, logger
storage = Storage.new config.db_path, logger

context = Context.new config, logger, library, storage

server = Server.new context
server.start
