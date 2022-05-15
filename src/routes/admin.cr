require "sanitize"

struct AdminRouter
  def initialize
    get "/admin" do |env|
      storage = Storage.default
      missing_count = storage.missing_titles.size +
                      storage.missing_entries.size
      layout "admin"
    end

    get "/admin/user" do |env|
      users = Storage.default.list_users
      username = get_username env
      layout "user"
    end

    get "/admin/user/edit" do |env|
      sanitizer = Sanitize::Policy::Text.new
      username = env.params.query["username"]?.try { |s| sanitizer.process s }
      admin = env.params.query["admin"]?
      if admin
        admin = admin == "true"
      end
      error = env.params.query["error"]?.try { |s| sanitizer.process s }
      new_user = username.nil? && admin.nil?
      layout "user-edit"
    end

    post "/admin/user/edit" do |env|
      # creating new user
      username = env.params.body["username"]
      password = env.params.body["password"]
      # if `admin` is unchecked, the body hash
      #   would not contain `admin`
      admin = !env.params.body["admin"]?.nil?

      Storage.default.new_user username, password, admin

      redirect env, "/admin/user"
    rescue e
      Logger.error e
      redirect_url = URI.new \
        path: "/admin/user/edit",
        query: hash_to_query({"error" => e.message})
      redirect env, redirect_url.to_s
    end

    post "/admin/user/edit/:original_username" do |env|
      # editing existing user
      username = env.params.body["username"]
      password = env.params.body["password"]
      # if `admin` is unchecked, the body hash would not contain `admin`
      admin = !env.params.body["admin"]?.nil?
      original_username = env.params.url["original_username"]

      Storage.default.update_user \
        original_username, username, password, admin

      redirect env, "/admin/user"
    rescue e
      Logger.error e
      redirect_url = URI.new \
        path: "/admin/user/edit",
        query: hash_to_query({"username" => original_username, \
                                 "admin" => admin, "error" => e.message})
      redirect env, redirect_url.to_s
    end

    get "/admin/downloads" do |env|
      layout "download-manager"
    end

    get "/admin/subscriptions" do |env|
      layout "subscription-manager"
    end

    get "/admin/missing" do |env|
      layout "missing-items"
    end
  end
end
