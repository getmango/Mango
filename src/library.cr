require "zip"
require "mime"
require "json"
require "uri"
require "./util"

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
    file = Zip::File.new path
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
    url = "/api/page/#{@title_id}/#{@id}/1"
    TitleInfo.new @book.dir do |info|
      info_url = info.entry_cover_url[@title]?
      unless info_url.nil? || info_url.empty?
        url = info_url
      end
    end
    url
  end

  def read_page(page_num)
    Zip::File.open @zip_path do |file|
      page = file.entries
        .select { |e|
          ["image/jpeg", "image/png"].includes? \
            MIME.from_filename? e.filename
        }
        .sort { |a, b|
          compare_alphanumerically a.filename, b.filename
        }
        .[page_num - 1]
      page.open do |io|
        slice = Bytes.new page.uncompressed_size
        bytes_read = io.read_fully? slice
        unless bytes_read
          return nil
        end
        return Image.new slice, MIME.from_filename(page.filename),
          page.filename, bytes_read
      end
    end
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
      if [".zip", ".cbz"].includes? File.extname path
        zip_exception = validate_zip path
        unless zip_exception.nil?
          Logger.warn "File #{path} is corrupted or is not a valid zip " \
                      "archive. Ignoring it."
          Logger.debug "Zip error: #{zip_exception}"
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

  def parents
    ary = [] of Title
    tid = @parent_id
    while !tid.empty?
      title = @library.get_title! tid
      ary << title
      tid = title.parent_id
    end
    ary
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
    url = "img/icon.png"
    if @entries.size > 0
      url = @entries[0].cover_url
    end
    TitleInfo.new @dir do |info|
      info_url = info.cover_url
      unless info_url.nil? || info_url.empty?
        url = info_url
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
      save_progress username, e.title, e.pages
    end
    titles.each do |t|
      t.read_all username
    end
  end

  # Set the reading progress of all entries and nested libraries to 0%
  def unread_all(username)
    @entries.each do |e|
      save_progress username, e.title, 0
    end
    titles.each do |t|
      t.unread_all username
    end
  end

  # For backward backward compatibility with v0.1.0, we save entry titles
  #   instead of IDs in info.json
  def save_progress(username, entry, page)
    TitleInfo.new @dir do |info|
      if info.progress[username]?.nil?
        info.progress[username] = {entry => page}
      else
        info.progress[username][entry] = page
      end
      info.save
    end
  end

  def load_progress(username, entry)
    progress = 0
    TitleInfo.new @dir do |info|
      unless info.progress[username]?.nil? ||
             info.progress[username][entry]?.nil?
        progress = info.progress[username][entry]
      end
    end
    progress
  end

  def load_percetage(username, entry)
    page = load_progress username, entry
    entry_obj = @entries.find { |e| e.title == entry }
    return 0.0 if entry_obj.nil?
    page / entry_obj.pages
  end

  def load_percetage(username)
    return 0.0 if @entries.empty?
    read_pages = total_pages = 0
    @entries.each do |e|
      read_pages += load_progress username, e.title
      total_pages += e.pages
    end
    read_pages / total_pages
  end

  def next_entry(current_entry_obj)
    idx = @entries.index current_entry_obj
    return nil if idx.nil? || idx == @entries.size - 1
    @entries[idx + 1]
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
end
