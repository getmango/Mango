require "yaml"

class Config
  include YAML::Serializable

  @[YAML::Field(ignore: true)]
  property path : String = ""
  property host : String = "0.0.0.0"
  property port : Int32 = 9000
  property base_url : String = "/"
  property session_secret : String = "mango-session-secret"
  property library_path : String = "~/mango/library"
  property library_cache_path = "~/mango/library.yml.gz"
  property db_path : String = "~/mango/mango.db"
  property queue_db_path : String = "~/mango/queue.db"
  property scan_interval_minutes : Int32 = 5
  property thumbnail_generation_interval_hours : Int32 = 24
  property log_level : String = "info"
  property upload_path : String = "~/mango/uploads"
  property plugin_path : String = "~/mango/plugins"
  property download_timeout_seconds : Int32 = 30
  property cache_enabled = false
  property cache_size_mbs = 50
  property cache_log_enabled = true
  property disable_login = false
  property default_username = ""
  property auth_proxy_header_name = ""

  @@singlet : Config?

  def self.current
    @@singlet.not_nil!
  end

  def set_current
    @@singlet = self
  end

  def self.load(path : String?)
    path = "~/.config/mango/config.yml" if path.nil?
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
