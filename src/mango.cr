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

macro get_username(env)
	cookie = {{env}}.request.cookies.find { |c| c.name == "token" }
	next if cookie.nil?
	storage.verify_token cookie.value
end

def hash_to_query(hash)
	hash.map { |k, v| "#{k}=#{v}" }
		.join("&")
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

get "/admin" do |env|
	layout "admin"
end

get "/admin/user" do |env|
	users = storage.list_users
	username = get_username env
	layout "user"
end

get "/admin/user/edit" do |env|
	username = env.params.query["username"]?
	admin = env.params.query["admin"]?
	if admin
		admin = admin == "true"
	end
	error = env.params.query["error"]?
	current_user = get_username env
	new_user = username.nil? && admin.nil?
	layout "user-edit"
end

post "/admin/user/edit" do |env|
	# creating new user
	begin
		username = env.params.body["username"]
		password = env.params.body["password"]
		# if `admin` is unchecked, the body hash would not contain `admin`
		admin = !env.params.body["admin"]?.nil?

		if username.size < 3
			raise "Username should contain at least 3 characters"
		end
		if password.size < 6
			raise "Password should contain at least 6 characters"
		end

		storage.new_user username, password, admin

		env.redirect "/admin/user"
	rescue e
		puts e.message
		redirect_url = URI.new \
			path: "/admin/user/edit",\
			query: hash_to_query({"error" => e.message})
		env.redirect redirect_url.to_s
	end
end

post "/admin/user/edit/:original_username" do |env|
	# editing existing user
	begin
		username = env.params.body["username"]
		password = env.params.body["password"]
		# if `admin` is unchecked, the body hash would not contain `admin`
		admin = !env.params.body["admin"]?.nil?
		original_username = env.params.url["original_username"]

		if username.size < 3
			raise "Username should contain at least 3 characters"
		end
		if password.size != 0 && password.size < 6
			raise "Password should contain at least 6 characters"
		end

		storage.update_user original_username, username, password, admin

		env.redirect "/admin/user"
	rescue e
		puts e.message
		redirect_url = URI.new \
			path: "/admin/user/edit",\
			query: hash_to_query({"username" => original_username, \
						 "admin" => admin, "error" => e.message})
		env.redirect redirect_url.to_s
	end
end

get "/reader/:title/:entry" do |env|
	# We should save the reading progress, and ask the user if she wants to
	# start over or resume. For now we just start from page 0
	begin
		title = library.get_title env.params.url["title"]
		raise "" if title.nil?
		entry = title.get_entry env.params.url["entry"]
		raise "" if entry.nil?
		env.redirect "/reader/#{title.title}/#{entry.title}/0"
	rescue
		env.response.status_code = 404
	end
end

get "/reader/:title/:entry/:page" do |env|
	imgs_each_page = 5
	# here each :page contains `imgs_each_page` images
	begin
		title = library.get_title env.params.url["title"]
		raise "" if title.nil?
		entry = title.get_entry env.params.url["entry"]
		raise "" if entry.nil?
		page = env.params.url["page"].to_i
		raise "" if page * imgs_each_page >= entry.pages

		urls = ((page * imgs_each_page)...\
			[entry.pages, (page + 1) * imgs_each_page].min) \
			.map { |idx| "/api/page/#{title.title}/#{entry.title}/#{idx}" }
		next_url = "/reader/#{title.title}/#{entry.title}/#{page + 1}"
		next_url = nil if (page + 1) * imgs_each_page >= entry.pages
		render "src/views/reader.ecr"
	rescue
		env.response.status_code = 404
	end
end

get "/login" do |env|
	render "src/views/login.ecr"
end

get "/logout" do |env|
	begin
		cookie = env.request.cookies.find { |c| c.name == "token" }
		raise "" if cookie.nil?
		storage.logout cookie.value
	rescue
	ensure
		env.redirect "/login"
	end
end

post "/login" do |env|
	begin
		username = env.params.body["username"]
		password = env.params.body["password"]
		token = storage.verify_user username, password
		raise "" if token.nil?

		cookie = HTTP::Cookie.new "token", token
		env.response.cookies << cookie
		env.redirect "/"
	rescue
		env.redirect "/login"
	end
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
