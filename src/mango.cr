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
	send_file {{env}}, {{img}}.data, {{img}}.mime
end


get "/" do |env|
	titles = library.titles
	layout "index"
end

get "/book/:title" do |env|
	title = library.get_title env.params.url["title"]
	if title.nil?
		env.response.status_code = 404
		next
	end
	layout "title"
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

get "/api/page/:title/:entry/:page" do |env|
	begin
		title = env.params.url["title"]
		entry = env.params.url["entry"]
		page = env.params.url["page"].to_i

		t = library.get_title title
		raise "Title `#{title}` not found" if t.nil?
		e = t.get_entry entry
		raise "Entry `#{entry}` of `#{title}` not found" if e.nil?
		img = e.read_page page
		raise "Failed to load page #{page} of `#{title}/#{entry}`" if img.nil?

		send_img env, img
	rescue e
		STDERR.puts e
		env.response.status_code = 500
		e.message
	end
end

get "/api/book/:title" do |env|
	begin
		title = env.params.url["title"]

		t = library.get_title title
		raise "Title `#{title}` not found" if t.nil?

		env.response.content_type = "application/json"
		t.to_json
	rescue e
		STDERR.puts e
		env.response.status_code = 500
		e.message
	end
end

get "/api/book" do |env|
	env.response.content_type = "application/json"
	library.to_json
end


add_handler AuthHandler.new storage

Kemal.config.port = config.port
Kemal.run
