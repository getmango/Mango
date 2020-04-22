require "kemal"
require "../logger"

class LogHandler < Kemal::BaseLogHandler
  def initialize(@logger : Logger)
  end

  def call(env)
    elapsed_time = Time.measure { call_next env }
    elapsed_text = elapsed_text elapsed_time
    msg = "#{env.response.status_code} #{env.request.method}" \
          " #{env.request.resource} #{elapsed_text}"
    @logger.debug msg
    env
  end

  def write(msg)
    @logger.debug msg
  end

  private def elapsed_text(elapsed)
    millis = elapsed.total_milliseconds
    return "#{millis.round(2)}ms" if millis >= 1
    "#{(millis * 1000).round(2)}µs"
  end
end
