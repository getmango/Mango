require "kemal"
require "../util/*"

class UploadHandler < Kemal::Handler
  def initialize(@upload_dir : String)
  end

  def call(env)
    unless request_path_startswith(env, [UPLOAD_URL_PREFIX]) &&
           env.request.method == "GET"
      return call_next env
    end

    ary = env.request.path.split(File::SEPARATOR).select do |part|
      !part.empty?
    end
    ary[0] = @upload_dir
    path = File.join ary

    if File.exists? path
      send_file env, path
    else
      env.response.status_code = 404
    end
  end
end
