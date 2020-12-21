# Web related helper functions/macros

macro layout(name)
  base_url = Config.current.base_url
  begin
    is_admin = false
    if token = env.session.string? "token"
      is_admin = @context.storage.verify_admin token
    end
    page = {{name}}
    render "src/views/#{{{name}}}.html.ecr", "src/views/layout.html.ecr"
  rescue e
    message = e.to_s
    @context.error message
    render "src/views/message.html.ecr", "src/views/layout.html.ecr"
  end
end

macro send_img(env, img)
  send_file {{env}}, {{img}}.data, {{img}}.mime
end

macro get_username(env)
  # if the request gets here, it has gone through the auth handler, and
  #   we can be sure that a valid token exists, so we can use not_nil! here
  token = env.session.string "token"
  (@context.storage.verify_token token).not_nil!
end

def send_json(env, json)
  env.response.content_type = "application/json"
  env.response.print json
end

def send_attachment(env, path)
  send_file env, path, filename: File.basename(path), disposition: "attachment"
end

def redirect(env, path)
  base = Config.current.base_url
  env.redirect File.join base, path
end

def hash_to_query(hash)
  hash.map { |k, v| "#{k}=#{v}" }.join("&")
end

def request_path_startswith(env, ary)
  ary.each do |prefix|
    if env.request.path.starts_with? prefix
      return true
    end
  end
  false
end

def requesting_static_file(env)
  request_path_startswith env, STATIC_DIRS
end

macro render_xml(path)
  base_url = Config.current.base_url
  send_file env, ECR.render({{path}}).to_slice, "application/xml"
end

macro render_component(filename)
  render "src/views/components/#{{{filename}}}.html.ecr"
end

macro get_sort_opt
  sort_method = env.params.query["sort"]?

  if sort_method
    is_ascending = true

    ascend = env.params.query["ascend"]?
    if ascend && ascend.to_i? == 0
      is_ascending = false
    end

    sort_opt = SortOptions.new sort_method, is_ascending
  end
end

module HTTP
  class Client
    private def self.exec(uri : URI, tls : TLSContext = nil)
      previous_def uri, tls do |client, path|
        disable_ssl_verification = ENV["DISABLE_SSL_VERIFICATION"]? ||
                                   ENV["disable_ssl_verification"]?
        if disable_ssl_verification && client.tls?
          Logger.debug "Disabling SSL verification"
          client.tls.verify_mode = OpenSSL::SSL::VerifyMode::NONE
        end
        Logger.debug "Setting read timeout"
        client.read_timeout = Config.current.download_timeout_seconds.seconds
        Logger.debug "Requesting #{uri}"
        yield client, path
      end
    end
  end
end
