require "yaml"

class Config
  include YAML::Serializable

  property port : Int32 = 9000
  property base_url : String = "/"
  property library_path : String = File.expand_path "~/mango/library",
    home: true
  property db_path : String = File.expand_path "~/mango/mango.db", home: true
  @[YAML::Field(key: "scan_interval_minutes")]
  property scan_interval : Int32 = 5
  property log_level : String = "info"
  property upload_path : String = File.expand_path "~/mango/uploads",
    home: true
  property mangadex = Hash(String, String | Int32).new

  @[YAML::Field(ignore: true)]
  @mangadex_defaults = {
    "base_url"               => "https://mangadex.org",
    "api_url"                => "https://mangadex.org/api",
    "download_wait_seconds"  => 5,
    "download_retries"       => 4,
    "download_queue_db_path" => File.expand_path("~/mango/queue.db",
      home: true),
    "chapter_rename_rule" => "[Vol.{volume} ][Ch.{chapter} ]{title|id}",
    "manga_rename_rule"   => "{title}",
  }

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
      config.preprocess
      config.fill_defaults
      return config
    end
    puts "The config file #{cfg_path} does not exist." \
         " Do you want mango to dump the default config there? [Y/n]"
    input = gets
    if input && input.downcase == "n"
      abort "Aborting..."
    end
    default = self.allocate
    default.fill_defaults
    cfg_dir = File.dirname cfg_path
    unless Dir.exists? cfg_dir
      Dir.mkdir_p cfg_dir
    end
    File.write cfg_path, default.to_yaml
    puts "The config file has been created at #{cfg_path}."
    default
  end

  def fill_defaults
    {% for hash_name in ["mangadex"] %}
      @{{hash_name.id}}_defaults.map do |k, v|
        if @{{hash_name.id}}[k]?.nil?
          @{{hash_name.id}}[k] = v
        end
      end
    {% end %}
  end

  def preprocess
    unless base_url.starts_with? "/"
      raise "base url (#{base_url}) should start with `/`"
    end
    unless base_url.ends_with? "/"
      @base_url += "/"
    end
  end
end
