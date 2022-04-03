class CORSHandler < Kemal::Handler
  def call(env)
    if request_path_startswith env, ["/api"]
      env.response.headers["Access-Control-Allow-Origin"] = "*"
    end
    call_next env
  end
end
