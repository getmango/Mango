require "http_proxy"

# Monkey-patch `HTTP::Client` to make it respect the `*_PROXY`
#   environment variables
module HTTP
  class Client
    private def self.exec(uri : URI, tls : TLSContext = nil)
      Logger.debug "Setting proxy"
      previous_def uri, tls do |client, path|
        client.set_proxy get_proxy uri
        yield client, path
      end
    end
  end
end

private def get_proxy(uri : URI) : HTTP::Proxy::Client?
  no_proxy = ENV["no_proxy"]? || ENV["NO_PROXY"]?
  return if no_proxy &&
            no_proxy.split(",").any? &.== uri.hostname

  case uri.scheme
  when "http"
    env_to_proxy "http_proxy"
  when "https"
    env_to_proxy "https_proxy"
  else
    nil
  end
end

private def env_to_proxy(key : String) : HTTP::Proxy::Client?
  val = ENV[key.downcase]? || ENV[key.upcase]?
  return if val.nil?

  begin
    uri = URI.parse val
    HTTP::Proxy::Client.new uri.hostname.not_nil!, uri.port.not_nil!,
      username: uri.user, password: uri.password
  rescue
    nil
  end
end
