require "image_size"
require "yaml"

abstract class Entry
  getter id : String, book : Title, title : String,
    size : String, pages : Int32, mtime : Time,
    encoded_path : String, encoded_title : String, err_msg : String?

  def initialize(
    @id, @title, @book,
    @size, @pages, @mtime,
    @encoded_path, @encoded_title, @err_msg)
  end

  def self.new(ctx : YAML::ParseContext, node : YAML::Nodes::Node)
    # TODO: check node? and select proper subclass
    ZippedEntry.new ctx, node
  end

  def build_json(*, slim = false)
    JSON.build do |json|
      json.object do
        {% for str in %w(path title size id) %}
        json.field {{str}}, {{str.id}}
      {% end %}
        if err_msg
          json.field "err_msg", err_msg
        end
        json.field "title_id", @book.id
        json.field "title_title", @book.title
        json.field "sort_title", sort_title
        json.field "pages" { json.number @pages }
        unless slim
          json.field "display_name", @book.display_name @title
          json.field "cover_url", cover_url
          json.field "mtime" { json.number @mtime.to_unix }
        end
      end
    end
  end

  @[YAML::Field(ignore: true)]
  @sort_title : String?

  def sort_title
    sort_title_cached = @sort_title
    return sort_title_cached if sort_title_cached
    sort_title = @book.entry_sort_title_db id
    if sort_title
      @sort_title = sort_title
      return sort_title
    end
    @sort_title = @title
    @title
  end

  def set_sort_title(sort_title : String | Nil, username : String)
    Storage.default.set_entry_sort_title id, sort_title
    if sort_title == "" || sort_title.nil?
      @sort_title = nil
    else
      @sort_title = sort_title
    end

    @book.entry_sort_title_cache = nil
    @book.remove_sorted_entries_cache [SortMethod::Auto, SortMethod::Title],
      username
  end

  def sort_title_db
    @book.entry_sort_title_db @id
  end

  def display_name
    @book.display_name @title
  end

  def encoded_display_name
    URI.encode display_name
  end

  def cover_url
    return "#{Config.current.base_url}img/icons/icon_x192.png" if @err_msg

    unless @book.entry_cover_url_cache
      TitleInfo.new @book.dir do |info|
        @book.entry_cover_url_cache = info.entry_cover_url
      end
    end
    entry_cover_url = @book.entry_cover_url_cache

    url = "#{Config.current.base_url}api/cover/#{@book.id}/#{@id}"
    if entry_cover_url
      info_url = entry_cover_url[@title]?
      unless info_url.nil? || info_url.empty?
        url = File.join Config.current.base_url, info_url
      end
    end
    url
  end

  def next_entry(username)
    entries = @book.sorted_entries username
    idx = entries.index self
    return nil if idx.nil? || idx == entries.size - 1
    entries[idx + 1]
  end

  def previous_entry(username)
    entries = @book.sorted_entries username
    idx = entries.index self
    return nil if idx.nil? || idx == 0
    entries[idx - 1]
  end

  # For backward backward compatibility with v0.1.0, we save entry titles
  #   instead of IDs in info.json
  def save_progress(username, page)
    LRUCache.invalidate "#{@book.id}:#{username}:progress_sum"
    @book.parents.each do |parent|
      LRUCache.invalidate "#{parent.id}:#{username}:progress_sum"
    end
    @book.remove_sorted_caches [SortMethod::Progress], username

    TitleInfo.new @book.dir do |info|
      if info.progress[username]?.nil?
        info.progress[username] = {@title => page}
      else
        info.progress[username][@title] = page
      end
      # save last_read timestamp
      if info.last_read[username]?.nil?
        info.last_read[username] = {@title => Time.utc}
      else
        info.last_read[username][@title] = Time.utc
      end
      info.save
    end
  end

  def load_progress(username)
    progress = 0
    TitleInfo.new @book.dir do |info|
      unless info.progress[username]?.nil? ||
             info.progress[username][@title]?.nil?
        progress = info.progress[username][@title]
      end
    end
    [progress, @pages].min
  end

  def load_percentage(username)
    page = load_progress username
    page / @pages
  end

  def load_last_read(username)
    last_read = nil
    TitleInfo.new @book.dir do |info|
      unless info.last_read[username]?.nil? ||
             info.last_read[username][@title]?.nil?
        last_read = info.last_read[username][@title]
      end
    end
    last_read
  end

  def finished?(username)
    load_progress(username) == @pages
  end

  def started?(username)
    load_progress(username) > 0
  end

  def generate_thumbnail : Image?
    return if @err_msg

    img = read_page(1).not_nil!
    begin
      size = ImageSize.get img.data
      if size.height > size.width
        thumbnail = ImageSize.resize img.data, width: 200
      else
        thumbnail = ImageSize.resize img.data, height: 300
      end
      img.data = thumbnail
      img.size = thumbnail.size
      unless img.mime == "image/webp"
        # image_size.cr resizes non-webp images to jpg
        img.mime = "image/jpeg"
      end
      Storage.default.save_thumbnail @id, img
    rescue e
      Logger.warn "Failed to generate thumbnail for file #{path}. #{e}"
    end

    img
  end

  def get_thumbnail : Image?
    Storage.default.get_thumbnail @id
  end

  def date_added : Time
    date_added = nil
    TitleInfo.new @book.dir do |info|
      info_da = info.date_added[@title]?
      if info_da.nil?
        date_added = info.date_added[@title] = createtime
        info.save
      else
        date_added = info_da
      end
    end
    date_added.not_nil! # is it ok to set not_nil! here?
  end

  abstract def path : String

  abstract def createtime : Time

  abstract def read_page(page_num)

  abstract def page_dimensions

  abstract def exists? : Bool?
end

class ZippedEntry < Entry
  include YAML::Serializable

  getter zip_path : String

  def initialize(@zip_path, @book)
    storage = Storage.default
    @encoded_path = URI.encode @zip_path
    @title = File.basename @zip_path, File.extname @zip_path
    @encoded_title = URI.encode @title
    @size = (File.size @zip_path).humanize_bytes
    id = storage.get_entry_id @zip_path, File.signature(@zip_path)
    if id.nil?
      id = random_str
      storage.insert_entry_id({
        path:      @zip_path,
        id:        id,
        signature: File.signature(@zip_path).to_s,
      })
    end
    @id = id
    @mtime = File.info(@zip_path).modification_time

    unless File.readable? @zip_path
      @err_msg = "File #{@zip_path} is not readable."
      Logger.warn "#{@err_msg} Please make sure the " \
                  "file permission is configured correctly."
      return
    end

    archive_exception = validate_archive @zip_path
    unless archive_exception.nil?
      @err_msg = "Archive error: #{archive_exception}"
      Logger.warn "Unable to extract archive #{@zip_path}. " \
                  "Ignoring it. #{@err_msg}"
      return
    end

    file = ArchiveFile.new @zip_path
    @pages = file.entries.count do |e|
      SUPPORTED_IMG_TYPES.includes? \
        MIME.from_filename? e.filename
    end
    file.close
  end

  def path : String
    @zip_path
  end

  def createtime : Time
    ctime @zip_path
  end

  private def sorted_archive_entries
    ArchiveFile.open @zip_path do |file|
      entries = file.entries
        .select { |e|
          SUPPORTED_IMG_TYPES.includes? \
            MIME.from_filename? e.filename
        }
        .sort! { |a, b|
          compare_numerically a.filename, b.filename
        }
      yield file, entries
    end
  end

  def read_page(page_num)
    raise "Unreadble archive. #{@err_msg}" if @err_msg
    img = nil
    begin
      sorted_archive_entries do |file, entries|
        page = entries[page_num - 1]
        data = file.read_entry page
        if data
          img = Image.new data, MIME.from_filename(page.filename),
            page.filename, data.size
        end
      end
    rescue e
      Logger.warn "Unable to read page #{page_num} of #{@zip_path}. Error: #{e}"
    end
    img
  end

  def page_dimensions
    sizes = [] of Hash(String, Int32)
    sorted_archive_entries do |file, entries|
      entries.each_with_index do |e, i|
        begin
          data = file.read_entry(e).not_nil!
          size = ImageSize.get data
          sizes << {
            "width"  => size.width,
            "height" => size.height,
          }
        rescue e
          Logger.warn "Failed to read page #{i} of entry #{zip_path}. #{e}"
          sizes << {"width" => 1000_i32, "height" => 1000_i32}
        end
      end
    end
    sizes
  end

  def exists? : Bool
    File.exists? @zip_path
  end
end

class DirectoryEntry < Entry
  include YAML::Serializable

  getter dir_path : String

  @[YAML::Field(ignore: true)]
  @sorted_files : Array(String)?

  @signature : String

  def initialize(@dir_path, @book)
    storage = Storage.default
    @encoded_path = URI.encode @dir_path
    @title = File.basename @dir_path
    @encoded_title = URI.encode @title

    unless File.readable? @dir_path
      @err_msg = "Directory #{@dir_path} is not readable."
      Logger.warn "#{@err_msg} Please make sure the " \
                  "file permission is configured correctly."
      return
    end

    unless DirectoryEntry.validate_directory_entry @dir_path
      @err_msg = "Directory #{@dir_path} is not valid directory entry."
      Logger.warn "#{@err_msg} Please make sure the " \
                  "directory has valid images."
      return
    end

    size_sum = 0
    sorted_files.each do |file_path|
      size_sum += File.size file_path
    end
    @size = size_sum.humanize_bytes

    @signature = Dir.directory_entry_signature @dir_path
    id = storage.get_entry_id @dir_path, @signature
    if id.nil?
      id = random_str
      storage.insert_entry_id({
        path:      @dir_path,
        id:        id,
        signature: @signature,
      })
    end
    @id = id

    mtimes = sorted_files.map { |file_path| File.info(file_path).modification_time }
    @mtime = mtimes.max

    @pages = sorted_files.size
  end

  def path : String
    @dir_path
  end

  def createtime : Time
    ctime @dir_path
  end

  def read_page(page_num)
    img = nil
    begin
      files = sorted_files
      file_path = files[page_num - 1]
      data = File.read(file_path).to_slice
      if data
        img = Image.new data, MIME.from_filename(file_path),
          File.basename(file_path), data.size
      end
    rescue e
      Logger.warn "Unable to read page #{page_num} of #{@dir_path}. Error: #{e}"
    end
    img
  end

  def page_dimensions
    sizes = [] of Hash(String, Int32)
    sorted_files.each_with_index do |path, i|
      data = File.read(path).to_slice
      begin
        data.not_nil!
        size = ImageSize.get data
        sizes << {
          "width"  => size.width,
          "height" => size.height,
        }
      rescue e
        Logger.warn "Failed to read page #{i} of entry #{@dir_path}. #{e}"
        sizes << {"width" => 1000_i32, "height" => 1000_i32}
      end
    end
    sizes
  end

  def exists? : Bool
    existence = File.exists? @dir_path
    return false unless existence
    files = DirectoryEntry.get_valid_files @dir_path
    signature = Dir.directory_entry_signature @dir_path
    existence = files.size > 0 && @signature == signature
    @sorted_files = nil unless existence

    # For more efficient,
    # Fix a directory instance with new property
    # and return true
    existence
  end

  def sorted_files
    cached_sorted_files = @sorted_files
    return cached_sorted_files if cached_sorted_files
    @sorted_files = DirectoryEntry.get_valid_files_sorted @dir_path
    @sorted_files.not_nil!
  end

  def self.validate_directory_entry(dir_path)
    files = DirectoryEntry.get_valid_files dir_path
    files.size > 0
  end

  def self.get_valid_files(dir_path)
    files = [] of String
    Dir.entries(dir_path).each do |fn|
      next if fn.starts_with? "."
      path = File.join dir_path, fn
      next unless is_supported_image_file path
      next if File.directory? path
      next unless File.readable? path
      files << path
    end
    files
  end

  def self.get_valid_files_sorted(dir_path)
    files = DirectoryEntry.get_valid_files dir_path
    files.sort! { |a, b| compare_numerically a, b }
  end
end
