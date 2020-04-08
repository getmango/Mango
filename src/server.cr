require "kemal"
require "./context"
require "./auth_handler"
require "./static_handler"
require "./log_handler"
require "./util"
require "./routes/*"

class Server
  def initialize(@context : Context)
    error 403 do |env|
      message = "HTTP 403: You are not authorized to visit #{env.request.path}"
      layout "message"
    end
    error 404 do |env|
      message = "HTTP 404: Mango cannot find the page #{env.request.path}"
      layout "message"
    end
    error 500 do |env|
      message = "HTTP 500: Internal server error. Please try again later."
      layout "message"
    end

    MainRouter.new(@context).setup
    AdminRouter.new(@context).setup
    ReaderRouter.new(@context).setup
    APIRouter.new(@context).setup

    Kemal.config.logging = false
    add_handler LogHandler.new @context.logger
    add_handler AuthHandler.new @context.storage
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
    Kemal.config.port = @context.config.port
    Kemal.run
  end
end
