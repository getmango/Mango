class Library
  property dir : String, title_ids : Array(String), scan_interval : Int32,
    title_hash : Hash(String, Title)

  def self.default : self
    unless @@default
      @@default = new
    end
    @@default.not_nil!
  end

  def initialize
    register_mime_types

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

  def deep_titles
    titles + titles.map { |t| t.deep_titles }.flatten
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

    storage = Storage.new auto_close: false

    (Dir.entries @dir)
      .select { |fn| !fn.starts_with? "." }
      .map { |fn| File.join @dir, fn }
      .select { |path| File.directory? path }
      .map { |path| Title.new path, "", storage, self }
      .select { |title| !(title.entries.empty? && title.titles.empty?) }
      .sort { |a, b| a.title <=> b.title }
      .each do |title|
        @title_hash[title.id] = title
        @title_ids << title.id
      end

    storage.bulk_insert_ids
    storage.close

    Logger.debug "Scan completed"
  end

  def get_continue_reading_entries(username)
    cr_entries = deep_titles
      .map { |t| t.get_last_read_entry username }
      # Select elements with type `Entry` from the array and ignore all `Nil`s
      .select(Entry)[0..11]
      .map { |e|
        # Get the last read time of the entry. If it hasn't been started, get
        #   the last read time of the previous entry
        last_read = e.load_last_read username
        pe = e.previous_entry
        if last_read.nil? && pe
          last_read = pe.load_last_read username
        end
        {
          entry:      e,
          percentage: e.load_percentage(username),
          last_read:  last_read,
        }
      }

    # Sort by by last_read, most recent first (nils at the end)
    cr_entries.sort { |a, b|
      next 0 if a[:last_read].nil? && b[:last_read].nil?
      next 1 if a[:last_read].nil?
      next -1 if b[:last_read].nil?
      b[:last_read].not_nil! <=> a[:last_read].not_nil!
    }
  end

  alias RA = NamedTuple(
    entry: Entry,
    percentage: Float64,
    grouped_count: Int32)

  def get_recently_added_entries(username)
    recently_added = [] of RA
    last_date_added = nil

    titles.map { |t| t.deep_entries_with_date_added }.flatten
      .select { |e| e[:date_added] > 1.month.ago }
      .sort { |a, b| b[:date_added] <=> a[:date_added] }
      .each do |e|
        break if recently_added.size > 12
        last = recently_added.last?
        if last && e[:entry].book.id == last[:entry].book.id &&
           (e[:date_added] - last_date_added.not_nil!).duration < 1.day
          # A NamedTuple is immutable, so we have to cast it to a Hash first
          last_hash = last.to_h
          count = last_hash[:grouped_count].as(Int32)
          last_hash[:grouped_count] = count + 1
          # Setting the percentage to a negative value will hide the
          #   percentage badge on the card
          last_hash[:percentage] = -1.0
          recently_added[recently_added.size - 1] = RA.from last_hash
        else
          last_date_added = e[:date_added]
          recently_added << {
            entry:         e[:entry],
            percentage:    e[:entry].load_percentage(username),
            grouped_count: 1,
          }
        end
      end

    recently_added[0..11]
  end

  def sorted_titles(username, opt : SortOptions? = nil)
    if opt.nil?
      opt = SortOptions.from_info_json @dir, username
    else
      TitleInfo.new @dir do |info|
        info.sort_by[username] = opt.to_tuple
        info.save
      end
    end

    # This is a hack to bypass a compiler bug
    ary = titles

    case opt.not_nil!.method
    when .time_modified?
      ary.sort! { |a, b| (a.mtime <=> b.mtime).or \
        compare_numerically a.title, b.title }
    when .progress?
      ary.sort! do |a, b|
        (a.load_percentage(username) <=> b.load_percentage(username)).or \
          compare_numerically a.title, b.title
      end
    else
      unless opt.method.auto?
        Logger.warn "Unknown sorting method #{opt.not_nil!.method}. Using " \
                    "Auto instead"
      end
      ary.sort! { |a, b| compare_numerically a.title, b.title }
    end

    ary.reverse! unless opt.not_nil!.ascend

    ary
  end
end
