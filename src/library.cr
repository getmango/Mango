require "mime"
require "json"
require "uri"
require "./util"
require "./archive"

struct Image
  property data : Bytes
  property mime : String
  property filename : String
  property size : Int32

  def initialize(@data, @mime, @filename, @size)
  end
end

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
      ["image/jpeg", "image/png"].includes? \
        MIME.from_filename? e.filename
    end
    file.close
    @id = storage.get_id @zip_path, false
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
          ["image/jpeg", "image/png"].includes? \
            MIME.from_filename? e.filename
        }
        .sort { |a, b|
          compare_alphanumerically a.filename, b.filename
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

  def next_entry
    idx = @book.entries.index self
    return nil if idx.nil? || idx == @book.entries.size - 1
    @book.entries[idx + 1]
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
    progress
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
end

class Title
  property dir : String, parent_id : String, title_ids : Array(String),
    entries : Array(Entry), title : String, id : String,
    encoded_title : String, mtime : Time

  def initialize(@dir : String, @parent_id, storage,
                 @library : Library)
    @id = storage.get_id @dir, true
    @title = File.basename dir
    @encoded_title = URI.encode @title
    @title_ids = [] of String
    @entries = [] of Entry
    @mtime = File.info(dir).modification_time

    Dir.entries(dir).each do |fn|
      next if fn.starts_with? "."
      path = File.join dir, fn
      if File.directory? path
        title = Title.new path, @id, storage, library
        next if title.entries.size == 0 && title.titles.size == 0
        @library.title_hash[title.id] = title
        @title_ids << title.id
        next
      end
      if [".zip", ".cbz", ".rar", ".cbr"].includes? File.extname path
        unless File.readable? path
          Logger.warn "File #{path} is not readable. Please make sure the " \
                      "file permission is configured correctly."
          next
        end
        archive_exception = validate_archive path
        unless archive_exception.nil?
          Logger.warn "Unable to extract archive #{path}. Ignoring it. " \
                      "Archive error: #{archive_exception}"
          next
        end
        entry = Entry.new path, self, @id, storage
        @entries << entry if entry.pages > 0
      end
    end

    mtimes = [@mtime]
    mtimes += @title_ids.map { |e| @library.title_hash[e].mtime }
    mtimes += @entries.map { |e| e.mtime }
    @mtime = mtimes.max

    @title_ids.sort! do |a, b|
      compare_alphanumerically @library.title_hash[a].title,
        @library.title_hash[b].title
    end
    @entries.sort! do |a, b|
      compare_alphanumerically a.title, b.title
    end
  end

  def to_json(json : JSON::Builder)
    json.object do
      {% for str in ["dir", "title", "id", "encoded_title"] %}
        json.field {{str}}, @{{str.id}}
      {% end %}
      json.field "display_name", display_name
      json.field "cover_url", cover_url
      json.field "mtime" { json.number @mtime.to_unix }
      json.field "titles" do
        json.raw self.titles.to_json
      end
      json.field "entries" do
        json.raw @entries.to_json
      end
      json.field "parents" do
        json.array do
          self.parents.each do |title|
            json.object do
              json.field "title", title.title
              json.field "id", title.id
            end
          end
        end
      end
    end
  end

  def titles
    @title_ids.map { |tid| @library.get_title! tid }
  end

  # Get all entries, including entries in nested titles
  def deep_entries
    return @entries if title_ids.empty?
    @entries + titles.map { |t| t.deep_entries }.flatten
  end

  def parents
    ary = [] of Title
    tid = @parent_id
    while !tid.empty?
      title = @library.get_title! tid
      ary << title
      tid = title.parent_id
    end
    ary.reverse
  end

  def size
    @entries.size + @title_ids.size
  end

  def get_entry(eid)
    @entries.find { |e| e.id == eid }
  end

  def display_name
    dn = @title
    TitleInfo.new @dir do |info|
      info_dn = info.display_name
      dn = info_dn unless info_dn.empty?
    end
    dn
  end

  def encoded_display_name
    URI.encode display_name
  end

  def display_name(entry_name)
    dn = entry_name
    TitleInfo.new @dir do |info|
      info_dn = info.entry_display_name[entry_name]?
      unless info_dn.nil? || info_dn.empty?
        dn = info_dn
      end
    end
    dn
  end

  def set_display_name(dn)
    TitleInfo.new @dir do |info|
      info.display_name = dn
      info.save
    end
  end

  def set_display_name(entry_name : String, dn)
    TitleInfo.new @dir do |info|
      info.entry_display_name[entry_name] = dn
      info.save
    end
  end

  def cover_url
    url = "#{Config.current.base_url}img/icon.png"
    if @entries.size > 0
      url = @entries[0].cover_url
    end
    TitleInfo.new @dir do |info|
      info_url = info.cover_url
      unless info_url.nil? || info_url.empty?
        url = File.join Config.current.base_url, info_url
      end
    end
    url
  end

  def set_cover_url(url : String)
    TitleInfo.new @dir do |info|
      info.cover_url = url
      info.save
    end
  end

  def set_cover_url(entry_name : String, url : String)
    TitleInfo.new @dir do |info|
      info.entry_cover_url[entry_name] = url
      info.save
    end
  end

  # Set the reading progress of all entries and nested libraries to 100%
  def read_all(username)
    @entries.each do |e|
      e.save_progress username, e.pages
    end
    titles.each do |t|
      t.read_all username
    end
  end

  # Set the reading progress of all entries and nested libraries to 0%
  def unread_all(username)
    @entries.each do |e|
      e.save_progress username, 0
    end
    titles.each do |t|
      t.unread_all username
    end
  end

  def deep_read_page_count(username) : Int32
    entries.map { |e| e.load_progress username }.sum +
      titles.map { |t| t.deep_read_page_count username }.flatten.sum
  end

  def deep_total_page_count : Int32
    entries.map { |e| e.pages }.sum +
      titles.map { |t| t.deep_total_page_count }.flatten.sum
  end

  def load_percentage(username)
    deep_read_page_count(username) / deep_total_page_count
  end

  def get_continue_reading_entry(username)
    in_progress_entries = @entries.select do |e|
      load_progress(username, e.title) > 0
    end
    return nil if in_progress_entries.empty?

    latest_read_entry = in_progress_entries[-1]
    if load_progress(username, latest_read_entry.title) ==
         latest_read_entry.pages
      next_entry latest_read_entry
    else
      latest_read_entry
    end
  end
end

class TitleInfo
  include JSON::Serializable

  property comment = "Generated by Mango. DO NOT EDIT!"
  property progress = {} of String => Hash(String, Int32)
  property display_name = ""
  property entry_display_name = {} of String => String
  property cover_url = ""
  property entry_cover_url = {} of String => String
  property last_read = {} of String => Hash(String, Time)
  property date_added = {} of String => Time

  @[JSON::Field(ignore: true)]
  property dir : String = ""

  @@mutex_hash = {} of String => Mutex

  def self.new(dir, &)
    if @@mutex_hash[dir]?
      mutex = @@mutex_hash[dir]
    else
      mutex = Mutex.new
      @@mutex_hash[dir] = mutex
    end
    mutex.synchronize do
      instance = TitleInfo.allocate
      json_path = File.join dir, "info.json"
      if File.exists? json_path
        instance = TitleInfo.from_json File.read json_path
      end
      instance.dir = dir
      yield instance
    end
  end

  def save
    json_path = File.join @dir, "info.json"
    File.write json_path, self.to_pretty_json
  end
end

class Library
  property dir : String, title_ids : Array(String), scan_interval : Int32,
    storage : Storage, title_hash : Hash(String, Title)

  def self.default : self
    unless @@default
      @@default = new
    end
    @@default.not_nil!
  end

  def initialize
    @storage = Storage.default
    @dir = Config.current.library_path
    @scan_interval = Config.current.scan_interval
    # explicitly initialize @titles to bypass the compiler check. it will
    #   be filled with actual Titles in the `scan` call below
    @title_ids = [] of String
    @title_hash = {} of String => Title

    return scan if @scan_interval < 1
    spawn do
      loop do
        start = Time.local
        scan
        ms = (Time.local - start).total_milliseconds
        Logger.info "Scanned #{@title_ids.size} titles in #{ms}ms"
        sleep @scan_interval * 60
      end
    end
  end

  def titles
    @title_ids.map { |tid| self.get_title!(tid) }
  end

  def to_json(json : JSON::Builder)
    json.object do
      json.field "dir", @dir
      json.field "titles" do
        json.raw self.titles.to_json
      end
    end
  end

  def get_title(tid)
    @title_hash[tid]?
  end

  def get_title!(tid)
    @title_hash[tid]
  end

  def scan
    unless Dir.exists? @dir
      Logger.info "The library directory #{@dir} does not exist. " \
                  "Attempting to create it"
      Dir.mkdir_p @dir
    end
    @title_ids.clear
    (Dir.entries @dir)
      .select { |fn| !fn.starts_with? "." }
      .map { |fn| File.join @dir, fn }
      .select { |path| File.directory? path }
      .map { |path| Title.new path, "", @storage, self }
      .select { |title| !(title.entries.empty? && title.titles.empty?) }
      .sort { |a, b| a.title <=> b.title }
      .each do |title|
        @title_hash[title.id] = title
        @title_ids << title.id
      end
    Logger.debug "Scan completed"
  end

  def get_continue_reading_entries(username)
    # map: get the continue-reading entry or nil for each Title
    # select: select only entries (and ignore Nil's) from the array
    #   produced by map
    continue_reading_entries = titles.map { |t|
      get_continue_reading_entry username, t
    }.select Entry

    continue_reading = continue_reading_entries.map { |e|
      {
        entry:      e,
        percentage: e.load_percentage(username),
        last_read:  get_relevant_last_read(username, e),
      }
    }

    # Sort by by last_read, most recent first (nils at the end)
    continue_reading.sort! { |a, b|
      next 0 if a[:last_read].nil? && b[:last_read].nil?
      next 1 if a[:last_read].nil?
      next -1 if b[:last_read].nil?
      b[:last_read].not_nil! <=> a[:last_read].not_nil!
    }[0..11]
  end

  def get_recently_added_entries(username)
    # Get all entries added within the last three months
    entries = titles.map { |t| t.deep_entries }
      .flatten
      .select { |e| e.date_added > 3.months.ago }

    # Group entries in a Hash by title ID
    grouped_entries = {} of String => Array(Entry)
    entries.each do |e|
      if grouped_entries.has_key? e.title_id
        grouped_entries[e.title_id].push e
      else
        grouped_entries[e.title_id] = [e]
      end
    end

    # Cast the Hash to an Array of Tuples and sort it by date_added
    grouped_ary = grouped_entries.to_a.sort do |a, b|
      date_added_a = a[1].map { |e| e.date_added }.max
      date_added_b = b[1].map { |e| e.date_added }.max
      date_added_b <=> date_added_a
    end

    recently_added = grouped_ary.map do |_, ary|
      # Get the most recently added entry in the group
      entry = ary.sort { |a, b| a.date_added <=> b.date_added }.last
      {
        entry:         entry,
        percentage:    entry.load_percentage(username),
        grouped_count: ary.size,
      }
    end

    recently_added[0..11]
  end

  private def get_continue_reading_entry(username, title)
    in_progress_entries = title.entries.select do |e|
      e.load_progress(username) > 0
    end
    return nil if in_progress_entries.empty?

    latest_read_entry = in_progress_entries[-1]
    if latest_read_entry.load_progress(username) ==
         latest_read_entry.pages
      latest_read_entry.next_entry
    else
      latest_read_entry
    end
  end

  private def get_relevant_last_read(username, entry_obj)
    last_read = entry_obj.load_last_read username
    # grab from previous entry if current entry hasn't been started yet
    if last_read.nil?
      previous_entry = entry_obj.previous_entry
      return previous_entry.load_last_read username if previous_entry
    end
    last_read
  end
end
