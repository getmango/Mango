require "./router"

class MainRouter < Router
  def initialize
    get "/login" do |env|
      base_url = Config.current.base_url
      render "src/views/login.ecr"
    end

    get "/logout" do |env|
      begin
        cookie = env.request.cookies.find do |c|
          c.name == "token-#{Config.current.port}"
        end.not_nil!
        @context.storage.logout cookie.value
      rescue e
        @context.error "Error when attempting to log out: #{e}"
      ensure
        redirect env, "/login"
      end
    end

    post "/login" do |env|
      begin
        username = env.params.body["username"]
        password = env.params.body["password"]
        token = @context.storage.verify_user(username, password).not_nil!

        set_token_cookie env, token
        redirect env, "/"
      rescue
        redirect env, "/login"
      end
    end

    get "/" do |env|
      begin
        titles = @context.library.titles
        username = get_username env
        percentage = titles.map &.load_percetage username
        layout "index"
      rescue e
        @context.error e
        env.response.status_code = 500
      end
    end

    get "/book/:title" do |env|
      begin
        title = (@context.library.get_title env.params.url["title"]).not_nil!
        username = get_username env
        percentage = title.entries.map { |e|
          title.load_percetage username, e.title
        }
        layout "title"
      rescue e
        @context.error e
        env.response.status_code = 404
      end
    end

    get "/download" do |env|
      mangadex_base_url = Config.current.mangadex["base_url"]
      layout "download"
    end
  end
end
