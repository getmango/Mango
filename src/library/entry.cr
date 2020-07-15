class Entry
  property zip_path : String, book : Title, title : String,
    size : String, pages : Int32, id : String, title_id : String,
    encoded_path : String, encoded_title : String, mtime : Time

  def initialize(path, @book, @title_id, storage)
    @zip_path = path
    @encoded_path = URI.encode path
    @title = File.basename path, File.extname path
    @encoded_title = URI.encode @title
    @size = (File.size path).humanize_bytes
    file = ArchiveFile.new path
    @pages = file.entries.count do |e|
      SUPPORTED_IMG_TYPES.includes? \
        MIME.from_filename? e.filename
    end
    file.close
    id = storage.get_id @zip_path, false
    if id.nil?
      id = random_str
      storage.insert_id({
        path:     @zip_path,
        id:       id,
        is_title: false,
      })
    end
    @id = id
    @mtime = File.info(@zip_path).modification_time
  end

  def to_json(json : JSON::Builder)
    json.object do
      {% for str in ["zip_path", "title", "size", "id", "title_id",
                     "encoded_path", "encoded_title"] %}
        json.field {{str}}, @{{str.id}}
      {% end %}
      json.field "display_name", @book.display_name @title
      json.field "cover_url", cover_url
      json.field "pages" { json.number @pages }
      json.field "mtime" { json.number @mtime.to_unix }
    end
  end

  def display_name
    @book.display_name @title
  end

  def encoded_display_name
    URI.encode display_name
  end

  def cover_url
    url = "#{Config.current.base_url}api/page/#{@title_id}/#{@id}/1"
    TitleInfo.new @book.dir do |info|
      info_url = info.entry_cover_url[@title]?
      unless info_url.nil? || info_url.empty?
        url = File.join Config.current.base_url, info_url
      end
    end
    url
  end

  def read_page(page_num)
    img = nil
    ArchiveFile.open @zip_path do |file|
      page = file.entries
        .select { |e|
          SUPPORTED_IMG_TYPES.includes? \
            MIME.from_filename? e.filename
        }
        .sort { |a, b|
          compare_numerically a.filename, b.filename
        }
        .[page_num - 1]
      data = file.read_entry page
      if data
        img = Image.new data, MIME.from_filename(page.filename), page.filename,
          data.size
      end
    end
    img
  end

  def next_entry(username)
    entries = @book.sorted_entries username
    idx = entries.index self
    return nil if idx.nil? || idx == entries.size - 1
    entries[idx + 1]
  end

  def previous_entry
    idx = @book.entries.index self
    return nil if idx.nil? || idx == 0
    @book.entries[idx - 1]
  end

  def date_added
    date_added = nil
    TitleInfo.new @book.dir do |info|
      info_da = info.date_added[@title]?
      if info_da.nil?
        date_added = info.date_added[@title] = ctime @zip_path
        info.save
      else
        date_added = info_da
      end
    end
    date_added.not_nil! # is it ok to set not_nil! here?
  end

  # For backward backward compatibility with v0.1.0, we save entry titles
  #   instead of IDs in info.json
  def save_progress(username, page)
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
end
