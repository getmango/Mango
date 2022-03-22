# Web related helper functions/macros

def is_admin?(env) : Bool
  is_admin = false
  if !Config.current.auth_proxy_header_name.empty? ||
     Config.current.disable_login
    is_admin = Storage.default.username_is_admin get_username env
  end

  # The token (if exists) takes precedence over other authentication methods.
  if token = env.session.string? "token"
    is_admin = Storage.default.verify_admin token
  end

  is_admin
end

macro layout(name)
  base_url = Config.current.base_url
  is_admin = is_admin? env
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

macro send_error_page(msg)
  message = {{msg}}
  base_url = Config.current.base_url
  is_admin = is_admin? env
  page = "Error"
  html = render "src/views/message.html.ecr", "src/views/layout.html.ecr"
  send_file env, html.to_slice, "text/html"
end

macro send_img(env, img)
  cors
  send_file {{env}}, {{img}}.data, {{img}}.mime
end

def get_token_from_auth_header(env) : String?
  value = env.request.headers["Authorization"]
  if value && value.starts_with? "Bearer"
    session_id = value.split(" ")[1]
    return Kemal::Session.get(session_id).try &.string? "token"
  end
end

macro get_username(env)
  begin
    # Check if we can get the session id from the cookie
    token = env.session.string? "token"
    if token.nil?
      # If not, check if we can get the session id from the auth header
      token = get_token_from_auth_header env
    end
    # If we still don't have a token, we handle it in `resuce` with `not_nil!`
    (Storage.default.verify_token token.not_nil!).not_nil!
  rescue e
    if Config.current.disable_login
      Config.current.default_username
    elsif (header = Config.current.auth_proxy_header_name) && !header.empty?
      env.request.headers[header]
    else
      raise e
    end
  end
end

macro cors
  env.response.headers["Access-Control-Allow-Methods"] = "HEAD,GET,PUT,POST," \
  "DELETE,OPTIONS"
  env.response.headers["Access-Control-Allow-Headers"] = "X-Requested-With," \
    "X-HTTP-Method-Override, Content-Type, Cache-Control, Accept," \
    "Authorization"
  env.response.headers["Access-Control-Allow-Origin"] = "*"
end

def send_json(env, json)
  cors
  env.response.content_type = "application/json"
  env.response.print json
end

def send_text(env, text)
  cors
  env.response.content_type = "text/plain"
  env.response.print text
end

def send_attachment(env, path)
  cors
  send_file env, path, filename: File.basename(path), disposition: "attachment"
end

def redirect(env, path)
  base = Config.current.base_url
  env.redirect File.join base, path
end

def hash_to_query(hash)
  hash.join "&" { |k, v| "#{k}=#{v}" }
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

macro get_and_save_sort_opt(dir)
  sort_method = env.params.query["sort"]?

  if sort_method
    is_ascending = true

    ascend = env.params.query["ascend"]?
    if ascend && ascend.to_i? == 0
      is_ascending = false
    end

    sort_opt = SortOptions.new sort_method, is_ascending

    TitleInfo.new {{dir}} do |info|
      info.sort_by[username] = sort_opt.to_tuple
      info.save
    end
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
