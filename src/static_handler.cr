require "baked_file_system"
require "kemal"
require "gzip"
require "./util"

class FS
	extend BakedFileSystem
	bake_folder "../public"
end

class StaticHandler < Kemal::Handler
	@dirs = ["/css", "/js"]

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
