require "kemal"
require "../storage"
require "../util"

class AuthHandler < Kemal::Handler
  # Some of the code is copied form kemalcr/kemal-basic-auth on GitHub

  BASIC        = "Basic"
  AUTH         = "Authorization"
  AUTH_MESSAGE = "Could not verify your access level for that URL.\n" \
                 "You have to login with proper credentials"
  HEADER_LOGIN_REQUIRED = "Basic realm=\"Login Required\""

  def initialize(@storage : Storage)
  end

  def require_basic_auth(env)
    env.response.status_code = 401
    env.response.headers["WWW-Authenticate"] = HEADER_LOGIN_REQUIRED
    env.response.print AUTH_MESSAGE
    call_next env
  end

  def validate_token(env)
    token = env.session.string? "token"
    !token.nil? && @storage.verify_token token
  end

  def validate_token_admin(env)
    token = env.session.string? "token"
    !token.nil? && @storage.verify_admin token
  end

  def validate_auth_header(env)
    if env.request.headers[AUTH]?
      if value = env.request.headers[AUTH]
        if value.size > 0 && value.starts_with?(BASIC)
          token = verify_user value
          return false if token.nil?

          env.session.string "token", token
          return true
        end
      end
    end
    false
  end

  def verify_user(value)
    username, password = Base64.decode_string(value[BASIC.size + 1..-1])
      .split(":")
    @storage.verify_user username, password
  end

  def handle_opds_auth(env)
    if validate_token(env) || validate_auth_header(env)
      call_next env
    else
      env.response.status_code = 401
      env.response.headers["WWW-Authenticate"] = HEADER_LOGIN_REQUIRED
      env.response.print AUTH_MESSAGE
    end
  end

  def handle_auth(env)
    if request_path_startswith env, ["/login", "/logout"] ||
                                    requesting_static_file env
      return call_next(env)
    end

    unless validate_token env
      env.session.string "callback", env.request.path
      return redirect env, "/login"
    end

    if request_path_startswith env, ["/admin", "/api/admin", "/download"]
      unless validate_token_admin env
        env.response.status_code = 403
      end
    end

    call_next env
  end

  def call(env)
    if request_path_startswith env, ["/opds"]
      handle_opds_auth env
    else
      handle_auth env
    end
  end
end
