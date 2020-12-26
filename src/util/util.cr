IMGS_PER_PAGE            = 5
ENTRIES_IN_HOME_SECTIONS = 8
UPLOAD_URL_PREFIX        = "/uploads"
STATIC_DIRS              = ["/css", "/js", "/img", "/favicon.ico"]

def random_str
  UUID.random.to_s.gsub "-", ""
end

# Works in all Unix systems. Follows https://github.com/crystal-lang/crystal/
#   blob/master/src/crystal/system/unix/file_info.cr#L42-L48
def ctime(file_path : String) : Time
  res = LibC.stat(file_path, out stat)
  raise "Unable to get ctime of file #{file_path}" if res != 0

  {% if flag?(:darwin) %}
    Time.new stat.st_ctimespec, Time::Location::UTC
  {% else %}
    Time.new stat.st_ctim, Time::Location::UTC
  {% end %}
end

def register_mime_types
  {
    ".zip" => "application/zip",
    ".rar" => "application/x-rar-compressed",
    ".cbz" => "application/vnd.comicbook+zip",
    ".cbr" => "application/vnd.comicbook-rar",
  }.each do |k, v|
    MIME.register k, v
  end
end

struct Int
  def or(other : Int)
    if self == 0
      other
    else
      self
    end
  end
end

struct Nil
  def or(other : Int)
    other
  end
end

macro use_default
  def self.default : self
    unless @@default
      @@default = new
    end
    @@default.not_nil!
  end
end

class String
  def alphanumeric_underscore?
    self.chars.all? { |c| c.alphanumeric? || c == '_' }
  end
end

def env_is_true?(key : String) : Bool
  val = ENV[key.upcase]? || ENV[key.downcase]?
  return false unless val
  val.downcase.in? "1", "true"
end
