# Web related helper functions/macros

macro check_admin_access
  is_admin = false
  # The token (if exists) takes precedence over the default user option.
  #   this is why we check the default username first before checking the
  #   token.
  if Config.current.disable_login
    is_admin = Storage.default.
      username_is_admin Config.current.default_username
  end
  if token = env.session.string? "token"
    is_admin = Storage.default.verify_admin token
  end
end

macro layout(name)
  base_url = Config.current.base_url
  check_admin_access
  begin
    page = {{name}}
    render "src/views/#{{{name}}}.html.ecr", "src/views/layout.html.ecr"
  rescue e
    message = e.to_s
    Logger.error message
    page = "Error"
    render "src/views/message.html.ecr", "src/views/layout.html.ecr"
  end
end

macro send_error_page
  base_url = Config.current.base_url
  check_admin_access
  page = "Error"
  html = render "src/views/message.html.ecr", "src/views/layout.html.ecr"
  send_file env, html.to_slice, "text/html"
end

macro send_img(env, img)
  send_file {{env}}, {{img}}.data, {{img}}.mime
end

macro get_username(env)
  begin
    token = env.session.string "token"
    (Storage.default.verify_token token).not_nil!
  rescue e
    if Config.current.disable_login
      Config.current.default_username
    else
      raise e
    end
  end
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
  ary.any? { |prefix| env.request.path.starts_with? prefix }
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
        if client.tls? && env_is_true? "DISABLE_SSL_VERIFICATION"
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
