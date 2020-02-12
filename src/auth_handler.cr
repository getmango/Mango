require "kemal"
require "./storage"

class AuthHandler < Kemal::Handler
	exclude ["/login"]
	exclude ["/login"], "POST"

	property storage : Storage

	def initialize(@storage)
	end

	def call(env)
		return call_next(env) if exclude_match?(env)

		env.request.cookies.each do |c|
			next if c.name != "token"
			if @storage.verify_token c.value
				return call_next env
			end
		end

		env.redirect "/login"
	end
end
