require "./server"
require "./config"
require "./library"
require "./storage"

config = Config.load
library = Library.new config.library_path
storage = Storage.new config.db_path

server = Server.new config, library, storage
server.start
