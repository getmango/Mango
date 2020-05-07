require "kemal"
require "./library"
require "./handlers/*"
require "./util"
require "./routes/*"

class Context
  property library : Library
  property storage : Storage
  property queue : MangaDex::Queue

  def self.default
    unless @@default
      @@default = new
    end
    @@default.not_nil!
  end

  def initialize
    @storage = Storage.default
    @library = Library.default
    @queue = MangaDex::Queue.default
  end

  {% for lvl in Logger::LEVELS %}
      def {{lvl.id}}(msg)
          Logger.{{lvl.id}} msg
      end
  {% end %}
end

class Server
  @context : Context = Context.default

  def initialize
    error 403 do |env|
      message = "HTTP 403: You are not authorized to visit #{env.request.path}"
      layout "message"
    end
    error 404 do |env|
      message = "HTTP 404: Mango cannot find the page #{env.request.path}"
      layout "message"
    end

    {% if flag?(:release) %}
      error 500 do |env|
        message = "HTTP 500: Internal server error. Please try again later."
        layout "message"
      end
    {% end %}

    MainRouter.new
    AdminRouter.new
    ReaderRouter.new
    APIRouter.new

    Kemal.config.logging = false
    add_handler LogHandler.new
    add_handler AuthHandler.new @context.storage
    add_handler UploadHandler.new Config.current.upload_path
    {% if flag?(:release) %}
      # when building for relase, embed the static files in binary
      @context.debug "We are in release mode. Using embedded static files."
      serve_static false
      add_handler StaticHandler.new
    {% end %}
  end

  def start
    @context.debug "Starting Kemal server"
    {% if flag?(:release) %}
      Kemal.config.env = "production"
    {% end %}
    Kemal.config.port = Config.current.port
    Kemal.run
  end
end
