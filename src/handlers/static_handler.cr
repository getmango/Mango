require "baked_file_system"
require "kemal"
require "../util/*"

class FS
  extend BakedFileSystem
  {% if flag?(:release) %}
    {% if read_file? "#{__DIR__}/../../dist/favicon.ico" %}
      {% puts "baking ../../dist" %}
      bake_folder "../../dist"
    {% else %}
      {% puts "baking ../../public" %}
      bake_folder "../../public"
    {% end %}
  {% end %}
end

class StaticHandler < Kemal::Handler
  def call(env)
    if requesting_static_file env
      file = FS.get? env.request.path
      return call_next env if file.nil?

      slice = Bytes.new file.size
      file.read slice
      return send_file env, slice, MIME.from_filename file.path
    end
    call_next env
  end
end
