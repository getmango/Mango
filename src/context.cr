require "./config"
require "./library"
require "./storage"
require "./logger"

class Context
  property config : Config
  property library : Library
  property storage : Storage
  property logger : Logger
  property queue : MangaDex::Queue

  def initialize(@config, @logger, @library, @storage, @queue)
  end

  {% for lvl in Logger::LEVELS %}
      def {{lvl.id}}(msg)
          @logger.{{lvl.id}} msg
      end
  {% end %}
end
