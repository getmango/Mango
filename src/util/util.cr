IMGS_PER_PAGE            = 5
ENTRIES_IN_HOME_SECTIONS = 8
UPLOAD_URL_PREFIX        = "/uploads"
STATIC_DIRS              = %w(/css /js /img /webfonts /favicon.ico /robots.txt
  /manifest.json)
SUPPORTED_FILE_EXTNAMES = [".zip", ".cbz", ".rar", ".cbr"]
SUPPORTED_IMG_TYPES     = %w(
  image/jpeg
  image/png
  image/webp
  image/apng
  image/avif
  image/gif
  image/svg+xml
  image/jxl
)

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
    # Comic Archives
    ".zip" => "application/zip",
    ".rar" => "application/x-rar-compressed",
    ".cbz" => "application/vnd.comicbook+zip",
    ".cbr" => "application/vnd.comicbook-rar",

    # Favicon
    ".ico" => "image/x-icon",

    # FontAwesome fonts
    ".woff"  => "font/woff",
    ".woff2" => "font/woff2",

    # Supported image formats. JPG, PNG, GIF, WebP, and SVG are already
    #   defiend by Crystal in `MIME.DEFAULT_TYPES`
    ".apng" => "image/apng",
    ".avif" => "image/avif",
    ".jxl"  => "image/jxl",
  }.each do |k, v|
    MIME.register k, v
  end
end

def is_supported_file(path)
  SUPPORTED_FILE_EXTNAMES.includes? File.extname(path).downcase
end

def is_supported_image_file(path)
  SUPPORTED_IMG_TYPES.includes? MIME.from_filename? path
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

def env_is_true?(key : String, default : Bool = false) : Bool
  val = ENV[key.upcase]? || ENV[key.downcase]?
  return default unless val
  val.downcase.in? "1", "true"
end

def sort_titles(titles : Array(Title), opt : SortOptions, username : String)
  cache_key = SortedTitlesCacheEntry.gen_key username, titles, opt
  cached_titles = LRUCache.get cache_key
  return cached_titles if cached_titles.is_a? Array(Title)

  case opt.method
  when .time_modified?
    ary = titles.sort { |a, b| (a.mtime <=> b.mtime).or \
      compare_numerically a.sort_title, b.sort_title }
  when .progress?
    ary = titles.sort do |a, b|
      (a.load_percentage(username) <=> b.load_percentage(username)).or \
        compare_numerically a.sort_title, b.sort_title
    end
  when .title?
    ary = titles.sort do |a, b|
      compare_numerically a.sort_title, b.sort_title
    end
  else
    unless opt.method.auto?
      Logger.warn "Unknown sorting method #{opt.not_nil!.method}. Using " \
                  "Auto instead"
    end
    ary = titles.sort { |a, b| compare_numerically a.sort_title, b.sort_title }
  end

  ary.reverse! unless opt.not_nil!.ascend

  LRUCache.set generate_cache_entry cache_key, ary
  ary
end

def remove_sorted_titles_cache(titles : Array(Title),
                               sort_methods : Array(SortMethod),
                               username : String)
  [false, true].each do |ascend|
    sort_methods.each do |sort_method|
      sorted_titles_cache_key = SortedTitlesCacheEntry.gen_key username,
        titles, SortOptions.new(sort_method, ascend)
      LRUCache.invalidate sorted_titles_cache_key
    end
  end
end

class String
  # Returns the similarity (in [0, 1]) of two paths.
  # For the two paths, separate them into arrays of components, count the
  #   number of matching components backwards, and divide the count by the
  #   number of components of the shorter path.
  def components_similarity(other : String) : Float64
    s, l = [self, other]
      .map { |str| Path.new(str).parts }
      .sort_by! &.size

    match = s.reverse.zip(l.reverse).count { |a, b| a == b }
    match / s.size
  end
end

# Does the followings:
#   - turns space-like characters into the normal whitespaces ( )
#   - strips and collapses spaces
#   - removes ASCII control characters
#   - replaces slashes (/) with underscores (_)
#   - removes leading dots (.)
#   - removes the following special characters: \:*?"<>|
#
# If the sanitized string is empty, returns a random string instead.
def sanitize_filename(str : String) : String
  sanitized = str
    .gsub(/\s+/, " ")
    .strip
    .gsub(/\//, "_")
    .gsub(/^[\.\s]+/, "")
    .gsub(/[\177\000-\031\\:\*\?\"<>\|]/, "")
  sanitized.size > 0 ? sanitized : random_str
end

def delete_cache_and_exit(path : String)
  File.delete path
  Logger.fatal "Invalid library cache deleted. Mango needs to " \
               "perform a full reset to recover from this. " \
               "Pleae restart Mango. This is NOT a bug."
  Logger.fatal "Exiting"
  exit 1
end
