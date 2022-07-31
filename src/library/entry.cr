require "image_size"

private def node_has_key(node : YAML::Nodes::Mapping, key : String)
  node.nodes
    .map_with_index { |n, i| {n, i} }
    .select(&.[1].even?)
    .map(&.[0])
    .select(YAML::Nodes::Scalar)
    .map(&.as(YAML::Nodes::Scalar).value)
    .includes? key
end

abstract class Entry
  getter id : String, book : Title, title : String, path : String,
    size : String, pages : Int32, mtime : Time,
    encoded_path : String, encoded_title : String, err_msg : String?

  def initialize(
    @id, @title, @book, @path,
    @size, @pages, @mtime,
    @encoded_path, @encoded_title, @err_msg
  )
  end

  def self.new(ctx : YAML::ParseContext, node : YAML::Nodes::Node)
    unless node.is_a? YAML::Nodes::Mapping
      raise "Unexpected node type in YAML"
    end
    # Doing YAML::Any.new(ctx, node) here causes a weird error, so
    #   instead we are using a more hacky approach (see `node_has_key`).
    # TODO: Use a more elegant approach
    if node_has_key node, "zip_path"
      ArchiveEntry.new ctx, node
    elsif node_has_key node, "dir_path"
      DirEntry.new ctx, node
    else
      raise "Unknown entry found in YAML cache. Try deleting the " \
            "`library.yml.gz` file"
    end
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
        json.field "zip_path", path # for API backward compatability
        json.field "path", path
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
    date_added = Time::UNIX_EPOCH
    TitleInfo.new @book.dir do |info|
      info_da = info.date_added[@title]?
      if info_da.nil?
        date_added = info.date_added[@title] = ctime path
        info.save
      else
        date_added = info_da
      end
    end
    date_added
  end

  # Hack to have abstract class methods
  # https://github.com/crystal-lang/crystal/issues/5956
  private module ClassMethods
    abstract def is_valid?(path : String) : Bool
  end

  macro inherited
    extend ClassMethods
  end

  abstract def read_page(page_num)

  abstract def page_dimensions

  abstract def examine : Bool?
end
