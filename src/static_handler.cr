require "baked_file_system"
require "kemal"
require "./util"

class FS
	extend BakedFileSystem
	{% if flag?(:release) %}
		{% if read_file? "#{__DIR__}/../dist/favicon.ico" %}
			{% puts "baking ../dist" %}
			bake_folder "../dist"
		{% else %}
			{% puts "baking ../public" %}
			bake_folder "../public"
		{% end %}
	{% end %}
end

class StaticHandler < Kemal::Handler
	@dirs = ["/css", "/js", "/img", "/favicon.ico"]

	def call(env)
		if request_path_startswith env, @dirs
			file = FS.get? env.request.path
			return call_next env if file.nil?

			slice = Bytes.new file.size
			file.read slice
			return send_file env, slice, file.mime_type
		end
		call_next env
	end
end
