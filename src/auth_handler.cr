require "kemal"

class AuthHandler < Kemal::Handler
	exclude ["/login"]
	def call(env)
		return call_next(env) if exclude_match?(env)
		my_cookie = HTTP::Cookie.new(
			name: "Example",
			value: "KemalCR"
		)
		env.response.cookies << my_cookie

		pp env.request.cookies
	end
end
