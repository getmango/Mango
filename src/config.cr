require "yaml"

class Config
  private OPTIONS = {
    "host"                                => "0.0.0.0",
    "port"                                => 9000,
    "base_url"                            => "/",
    "session_secret"                      => "mango-session-secret",
    "library_path"                        => "~/mango/library",
    "library_cache_path"                  => "~/mango/library.yml.gz",
    "db_path"                             => "~/mango.db",
    "queue_db_path"                       => "~/mango/queue.db",
    "scan_interval_minutes"               => 5,
    "thumbnail_generation_interval_hours" => 24,
    "log_level"                           => "info",
    "upload_path"                         => "~/mango/uploads",
    "plugin_path"                         => "~/mango/plugins",
    "download_timeout_seconds"            => 30,
    "cache_enabled"                       => true,
    "cache_size_mbs"                      => 50,
    "cache_log_enabled"                   => true,
    "disable_login"                       => false,
    "default_username"                    => "",
    "auth_proxy_header_name"              => "",
    "plugin_update_interval_hours"        => 24,
  }

  include YAML::Serializable

  @[YAML::Field(ignore: true)]
  property path : String = ""

  # Go through the options constant above and define them as properties.
  #   Allow setting the default values through environment variables.
  # Overall precedence: config file > environment variable > default value
  {% begin %}
    {% for k, v in OPTIONS %}
        {% if v.is_a? StringLiteral %}
          property {{k.id}} : String = ENV[{{k.upcase}}]? || {{ v }}
        {% elsif v.is_a? NumberLiteral %}
          property {{k.id}} : Int32 = (ENV[{{k.upcase}}]? || {{ v.id }}).to_i
        {% elsif v.is_a? BoolLiteral %}
          property {{k.id}} : Bool = env_is_true? {{ k.upcase }}, {{ v.id }}
        {% else %}
          raise "Unknown type in config option: {{ v.class_name.id }}"
        {% end %}
    {% end %}
  {% end %}

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
