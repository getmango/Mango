require "./router"

class AdminRouter < Router
	def setup
		get "/admin" do |env|
			layout "admin"
		end

		get "/admin/user" do |env|
			users = @context.storage.list_users
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
				# if `admin` is unchecked, the body hash
				# 	would not contain `admin`
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

				@context.storage.new_user username, password, admin

				env.redirect "/admin/user"
			rescue e
				@context.error e
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
				# if `admin` is unchecked, the body
				#	hash would not contain `admin`
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

				@context.storage.update_user \
					original_username, username, password, admin

				env.redirect "/admin/user"
			rescue e
				@context.error e
				redirect_url = URI.new \
					path: "/admin/user/edit",\
					query: hash_to_query({"username" => original_username, \
						   "admin" => admin, "error" => e.message})
					env.redirect redirect_url.to_s
			end
		end
	end
end
