require "kemal"
require "./config"
require "./library"
require "./storage"
require "./auth_handler"

config = Config.load
library = Library.new config.library_path
storage = Storage.new config.db_path

IMGS_PER_PAGE = 5

macro layout(name)
	render "src/views/#{{{name}}}.ecr", "src/views/layout.ecr"
end

macro send_img(env, img)
	send_file {{env}}, {{img}}.data, {{img}}.mime
end

macro get_username(env)
	# if the request gets here, its has gone through the auth handler, and
	# we can be sure that a valid token exists, so we can use not_nil! here
	cookie = {{env}}.request.cookies.find { |c| c.name == "token" }.not_nil!
	(storage.verify_token cookie.value).not_nil!
end

macro send_json(env, json)
	{{env}}.response.content_type = "application/json"
	{{json}}
end

def hash_to_query(hash)
	hash.map { |k, v| "#{k}=#{v}" }.join("&")
end

error 403 do |env|
	message = "You are not authorized to visit #{env.request.path}"
	layout "message"
end

get "/" do |env|
	begin
		titles = library.titles
		username = get_username env
		percentage = titles.map &.load_percetage username
		layout "index"
	rescue
		env.response.status_code = 500
	end
end

get "/book/:title" do |env|
	begin
		title = (library.get_title env.params.url["title"]).not_nil!
		username = get_username env
		percentage = title.entries.map { |e| title.load_percetage username,\
								   e.title }
		layout "title"
	rescue
		env.response.status_code = 404
	end
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
		if (username =~ /^[A-Za-z0-9_]+$/).nil?
			raise "Username should contain alphanumeric characters "\
				"and underscores only"
		end
		if password.size < 6
			raise "Password should contain at least 6 characters"
		end
		if (password =~ /^[[:ascii:]]+$/).nil?
			raise "password should contain ASCII characters only"
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
		if (username =~ /^[A-Za-z0-9_]+$/).nil?
			raise "Username should contain alphanumeric characters "\
				"and underscores only"
		end

		if password.size != 0
			if password.size < 6
				raise "Password should contain at least 6 characters"
			end
			if (password =~ /^[[:ascii:]]+$/).nil?
				raise "password should contain ASCII characters only"
			end
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
		title = (library.get_title env.params.url["title"]).not_nil!
		entry = (title.get_entry env.params.url["entry"]).not_nil!

		# load progress
		username = get_username env
		page = title.load_progress username, entry.title
		# we go back 2 * `IMGS_PER_PAGE` pages. the infinite scroll library
		# perloads a few pages in advance, and the user might not have actually
		# read them
		page = [page - 2 * IMGS_PER_PAGE, 1].max

		env.redirect "/reader/#{title.title}/#{entry.title}/#{page}"
	rescue
		env.response.status_code = 404
	end
end

get "/reader/:title/:entry/:page" do |env|
	begin
		title = (library.get_title env.params.url["title"]).not_nil!
		entry = (title.get_entry env.params.url["entry"]).not_nil!
		page = env.params.url["page"].to_i
		raise "" if page > entry.pages

		# save progress
		username = get_username env
		title.save_progress username, entry.title, page

		pages = (page...[entry.pages + 1, page + IMGS_PER_PAGE].min)
		urls = pages.map { |idx|
			"/api/page/#{title.title}/#{entry.title}/#{idx}" }
		reader_urls = pages.map { |idx|
			"/reader/#{title.title}/#{entry.title}/#{idx}" }
		next_page = page + IMGS_PER_PAGE
		next_url = next_page > entry.pages ? nil :
			"/reader/#{title.title}/#{entry.title}/#{next_page}"
		exit_url = "/book/#{title.title}"

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
		cookie = env.request.cookies.find { |c| c.name == "token" }.not_nil!
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
		token = storage.verify_user(username, password).not_nil!

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

		send_json env, t.to_json
	rescue e
		STDERR.puts e
		env.response.status_code = 500
		e.message
	end
end

get "/api/book" do |env|
	send_json env, library.to_json
end

post "/api/admin/scan" do |env|
	start = Time.utc
	library = Library.new config.library_path
	ms = (Time.utc - start).total_milliseconds
	send_json env, \
		{"milliseconds" => ms, "titles" => library.titles.size}.to_json
end

post "/api/admin/user/delete/:username" do |env|
	begin
		username = env.params.url["username"]
		storage.delete_user username
	rescue e
		send_json env, {"success" => false, "error" => e.message}.to_json
	else
		send_json env, {"success" => true}.to_json
	end
end

add_handler AuthHandler.new storage

{% if flag?(:release) %}
	Kemal.config.env = "production"
{% end %}
Kemal.config.port = config.port
Kemal.run
