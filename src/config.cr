require "yaml"

class Config
  include YAML::Serializable

  @[YAML::Field(ignore: true)]
  property path : String = ""
  property host : String = (ENV["LISTEN_HOST"]? || "0.0.0.0")
  property port : Int32 = (ENV["LISTEN_PORT"]? || 9000).to_i
  property base_url : String = (ENV["BASE_URL"]? || "/")
  property session_secret : String = \
        (ENV["SESSION_SECRET"]? || "mango-session-secret")
  property library_path : String = (ENV["LIBRARY_PATH"]? || "~/mango/library")
  property library_cache_path : String = \
        (ENV["LIBRARY_CACHE_PATH"]? || "~/mango/library.yml.gz")
  property db_path : String = (ENV["DB_PATH"]? || "~/mango/mango.db")
  property queue_db_path : String = \
        (ENV["QUEUE_DB_PATH"]? || "~/mango/queue.db")
  property scan_interval_minutes : Int32 = (ENV["SCAN_INTERVAL"]? || 5).to_i
  property thumbnail_generation_interval_hours : Int32 = \
        (ENV["THUMBNAIL_INTERVAL"]? || 24).to_i
  property log_level : String = (ENV["LOG_LEVEL"]? || "info")
  property upload_path : String = (ENV["UPLOAD_PATH"]? || "~/mango/uploads")
  property plugin_path : String = (ENV["PLUGIN_PATH"]? || "~/mango/plugins")
  property download_timeout_seconds : Int32 = \
        (ENV["DOWNLOAD_TIMEOUT"]? || 30).to_i
  property cache_enabled : Bool = env_is_true?("CACHE_ENABLED", true)
  property cache_size_mbs : Int32 = (ENV["CACHE_SIZE"]? || 50).to_i
  property cache_log_enabled : Bool = env_is_true?("CACHE_LOG_ENABLED", true)
  property disable_login : Bool = env_is_true?("DISABLE_LOGIN", false)
  property default_username : String = (ENV["DEFAULT_USERNAME"]? || "")
  property auth_proxy_header_name : String = (ENV["AUTH_PROXY_HEADER"]? || "")
  property plugin_update_interval_hours : Int32 = \
        (ENV["PLUGIN_UPDATE_INTERVAL"]? || 24).to_i

  @@singlet : Config?

  def self.current
    @@singlet.not_nil!
  end

  def set_current
    @@singlet = self
  end

  def self.load(path : String?)
    path = (ENV["CONFIG_PATH"]? || "~/.config/mango/config.yml") if path.nil?
    cfg_path = File.expand_path path, home: true
    if File.exists? cfg_path
      config = self.from_yaml File.read cfg_path
      config.path = path
      config.expand_paths
      config.preprocess
      return config
    end
    puts "The config file #{cfg_path} does not exist. " \
         "Dumping the default config there."
    default = self.allocate
    default.path = path
    default.expand_paths
    cfg_dir = File.dirname cfg_path
    unless Dir.exists? cfg_dir
      Dir.mkdir_p cfg_dir
    end
    File.write cfg_path, default.to_yaml
    puts "The config file has been created at #{cfg_path}."
    default
  end

  def expand_paths
    {% for p in %w(library library_cache db queue_db upload plugin) %}
      @{{p.id}}_path = File.expand_path @{{p.id}}_path, home: true
    {% end %}
  end

  def preprocess
    unless base_url.starts_with? "/"
      raise "base url (#{base_url}) should start with `/`"
    end
    unless base_url.ends_with? "/"
      @base_url += "/"
    end
    if disable_login && default_username.empty?
      raise "Login is disabled, but default username is not set. " \
            "Please set a default username"
    end
  end
end
