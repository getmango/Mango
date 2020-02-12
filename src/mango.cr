require "kemal"
require "./config"
require "./library"
require "./storage"
require "./auth_handler"

config = Config.load
library = Library.new config.library_path
storage = Storage.new config.db_path


macro layout(name)
	render "src/views/#{{{name}}}.ecr", "src/views/layout.ecr"
end

macro send_img(env, img)
	send_file env, image.data, image.mime
end


get "/" do |env|
	image = library.titles[0].get_cover
	unless image
		"Failed to load image"
		next
	end
	send_img env, image
end

get "/login" do |env|
	render "src/views/login.ecr"
end

post "/login" do |env|
	username = env.params.body["username"]
	password = env.params.body["password"]
	token = storage.verify_user username, password
	if token.nil?
		env.redirect "/login"
		next
	end

	cookie = HTTP::Cookie.new "token", token
	env.response.cookies << cookie
	env.redirect "/"
end

add_handler AuthHandler.new storage

Kemal.config.port = config.port
Kemal.run
