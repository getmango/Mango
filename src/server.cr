require "kemal"
require "kemal-session"
require "./library/*"
require "./handlers/*"
require "./util/*"
require "./routes/*"

class Server
  def initialize
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
    OPDSRouter.new

    {% for path in %w(/api/* /uploads/* /img/*) %}
      options {{path}} do |env|
        cors
        halt env
      end
    {% end %}

    static_headers do |response|
      response.headers.add("Access-Control-Allow-Origin", "*")
    end

    Kemal.config.logging = false
    add_handler LogHandler.new
    add_handler AuthHandler.new
    add_handler UploadHandler.new Config.current.upload_path
    {% if flag?(:release) %}
      # when building for relase, embed the static files in binary
      Logger.debug "We are in release mode. Using embedded static files."
      serve_static false
      add_handler StaticHandler.new
    {% end %}

    Kemal::Session.config do |c|
      c.timeout = 365.days
      c.secret = Config.current.session_secret
      c.cookie_name = "mango-sessid-#{Config.current.port}"
      c.path = Config.current.base_url
    end
  end

  def start
    Logger.debug "Starting Kemal server"
    {% if flag?(:release) %}
      Kemal.config.env = "production"
    {% end %}
    Kemal.config.host_binding = Config.current.host
    Kemal.config.port = Config.current.port
    Kemal.run
  end
end
