require "kemal"
require "./storage"
require "./util"

class AuthHandler < Kemal::Handler
	def initialize(@storage : Storage)
	end

	def call(env)
		return call_next(env) \
			if request_path_startswith env, ["/login", "/logout"]

		cookie = env.request.cookies.find { |c| c.name == "token" }
		if cookie.nil? || ! @storage.verify_token cookie.value
			return env.redirect "/login"
		end

		if request_path_startswith env, ["/admin", "/api/admin", "/download"]
			unless @storage.verify_admin cookie.value
				env.response.status_code = 403
			end
		end

		call_next env
	end
end
