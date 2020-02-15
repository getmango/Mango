require "kemal"
require "./storage"

def request_path_startswith(env, ary)
	ary.each do |prefix|
		if env.request.path.starts_with? prefix
			return true
		end
	end
	return false
end

class AuthHandler < Kemal::Handler
	exclude ["/login"]
	exclude ["/login"], "POST"

	property storage : Storage

	def initialize(@storage)
	end

	def call(env)
		return call_next(env) if exclude_match?(env)

		cookie = env.request.cookies.find { |c| c.name == "token" }
		if cookie.nil? || ! @storage.verify_token cookie.value
			return env.redirect "/login"
		end

		if request_path_startswith env, ["/admin", "/api/admin"]
			unless storage.verify_admin cookie.value
				env.response.status_code = 403
			end
		end

		call_next env
	end
end
