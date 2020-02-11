require "kemal"
require "./config"
require "./library"
require "./storage"
require "./auth_handler"

config = Config.load

library = Library.new config.library_path

storage = Storage.new config.db_path

get "/" do
	"Hello World!"
end

# APIs
get "/api/test" do |env|
	"Hello!"
end

add_handler AuthHandler.new

Kemal.config.port = config.port
Kemal.run
