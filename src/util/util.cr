IMGS_PER_PAGE     = 5
UPLOAD_URL_PREFIX = "/uploads"
STATIC_DIRS       = ["/css", "/js", "/img", "/favicon.ico"]

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
