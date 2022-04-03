class Library
  struct ThumbnailContext
    property current : Int32, total : Int32

    def initialize
      @current = 0
      @total = 0
    end

    def progress
      if total == 0
        0
      else
        current / total
      end
    end

    def reset
      @current = 0
      @total = 0
    end

    def increment
      @current += 1
    end
  end

  include YAML::Serializable

  getter dir : String, title_ids : Array(String),
    title_hash : Hash(String, Title)

  @[YAML::Field(ignore: true)]
  getter thumbnail_ctx = ThumbnailContext.new

  use_default

  def save_instance
    path = Config.current.library_cache_path
    Logger.debug "Caching library to #{path}"

    writer = Compress::Gzip::Writer.new path,
      Compress::Gzip::BEST_COMPRESSION
    writer.write self.to_yaml.to_slice
    writer.close
  end

  def self.load_instance
    path = Config.current.library_cache_path
    return unless File.exists? path

    Logger.debug "Loading cached library from #{path}"

    begin
      Compress::Gzip::Reader.open path do |content|
        loaded = Library.from_yaml content
        # We will have to do a full restart in these cases. Otherwise having
        #   two instances of the library will cause some weirdness.
        if loaded.dir != Config.current.library_path
          Logger.fatal "Cached library dir #{loaded.dir} does not match " \
                       "current library dir #{Config.current.library_path}. " \
                       "Deleting cache"
          delete_cache_and_exit path
        end
        if loaded.title_ids.size > 0 &&
           Storage.default.count_titles == 0
          Logger.fatal "The library cache is inconsistent with the DB. " \
                       "Deleting cache"
          delete_cache_and_exit path
        end
        @@default = loaded
        Logger.debug "Library cache loaded"
      end
      Library.default.register_jobs
    rescue e
      Logger.error e
    end
  end

  def initialize
    @dir = Config.current.library_path
    # explicitly initialize @titles to bypass the compiler check. it will
    #   be filled with actual Titles in the `scan` call below
    @title_ids = [] of String
    @title_hash = {} of String => Title

    register_jobs
  end

  protected def register_jobs
    register_mime_types

    scan_interval = Config.current.scan_interval_minutes
    if scan_interval < 1
      scan
    else
      spawn do
        loop do
          start = Time.local
          scan
          ms = (Time.local - start).total_milliseconds
          Logger.debug "Library initialized in #{ms}ms"
          sleep scan_interval.minutes
        end
      end
    end

    thumbnail_interval = Config.current.thumbnail_generation_interval_hours
    unless thumbnail_interval < 1
      spawn do
        loop do
          # Wait for scan to complete (in most cases)
          sleep 1.minutes
          generate_thumbnails
          sleep thumbnail_interval.hours
        end
      end
    end
  end

  def titles
    @title_ids.map { |tid| self.get_title!(tid) }
  end

  def sorted_titles(username, opt : SortOptions? = nil)
    if opt.nil?
      opt = SortOptions.from_info_json @dir, username
    end

    # Helper function from src/util/util.cr
    sort_titles titles, opt.not_nil!, username
  end

  def deep_titles
    titles + titles.flat_map &.deep_titles
  end

  def deep_entries
    titles.flat_map &.deep_entries
  end

  def build_json(*, slim = false, depth = -1, sort_context = nil,
                 percentage = false)
    _titles = if sort_context
                sorted_titles sort_context[:username],
                  sort_context[:opt]
              else
                self.titles
              end
    JSON.build do |json|
      json.object do
        json.field "dir", @dir
        json.field "titles" do
          json.array do
            _titles.each do |title|
              json.raw title.build_json(slim: slim, depth: depth,
                sort_context: sort_context, percentage: percentage)
            end
          end
        end
        if percentage && sort_context
          json.field "title_percentages" do
            json.array do
              _titles.each do |title|
                json.number title.load_percentage sort_context[:username]
              end
            end
          end
        end
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
    start = Time.local
    unless Dir.exists? @dir
      Logger.info "The library directory #{@dir} does not exist. " \
                  "Attempting to create it"
      Dir.mkdir_p @dir
    end

    storage = Storage.new auto_close: false

    examine_context : ExamineContext = {
      cached_contents_signature: {} of String => String,
      deleted_title_ids:         [] of String,
      deleted_entry_ids:         [] of String,
    }

    library_paths = (Dir.entries @dir)
      .select { |fn| !fn.starts_with? "." }
      .map { |fn| File.join @dir, fn }
    @title_ids.select! do |title_id|
      title = @title_hash[title_id]
      next false unless library_paths.includes? title.dir
      existence = title.examine examine_context
      unless existence
        examine_context["deleted_title_ids"].concat [title_id] +
                                                    title.deep_titles.map &.id
        examine_context["deleted_entry_ids"].concat title.deep_entries.map &.id
      end
      existence
    end
    remained_title_dirs = @title_ids.map { |id| title_hash[id].dir }
    examine_context["deleted_title_ids"].each do |title_id|
      @title_hash.delete title_id
    end

    cache = examine_context["cached_contents_signature"]
    library_paths
      .select { |path| !(remained_title_dirs.includes? path) }
      .select { |path| File.directory? path }
      .map { |path| Title.new path, "", cache }
      .select { |title| !(title.entries.empty? && title.titles.empty?) }
      .sort! { |a, b| a.sort_title <=> b.sort_title }
      .each do |title|
        @title_hash[title.id] = title
        @title_ids << title.id
      end

    storage.bulk_insert_ids
    storage.close

    ms = (Time.local - start).total_milliseconds
    Logger.info "Scanned #{@title_ids.size} titles in #{ms}ms"

    Storage.default.mark_unavailable examine_context["deleted_entry_ids"],
      examine_context["deleted_title_ids"]

    spawn do
      save_instance
    end
  end

  def get_continue_reading_entries(username)
    cr_entries = deep_titles
      .map(&.get_last_read_entry username)
      # Select elements with type `Entry` from the array and ignore all `Nil`s
      .select(Entry)[0...ENTRIES_IN_HOME_SECTIONS]
      .map { |e|
        # Get the last read time of the entry. If it hasn't been started, get
        #   the last read time of the previous entry
        last_read = e.load_last_read username
        pe = e.previous_entry username
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

    titles.flat_map(&.deep_entries_with_date_added)
      .select(&.[:date_added].> 1.month.ago)
      .sort! { |a, b| b[:date_added] <=> a[:date_added] }
      .each do |e|
        break if recently_added.size > 12
        last = recently_added.last?
        if last && e[:entry].book.id == last[:entry].book.id &&
           (e[:date_added] - last_date_added.not_nil!).abs < 1.day
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

    recently_added[0...ENTRIES_IN_HOME_SECTIONS]
  end

  def get_start_reading_titles(username)
    # Here we are not using `deep_titles` as it may cause unexpected behaviors
    # For example, consider the following nested titles:
    #   - One Puch Man
    #     - Vol. 1
    #     - Vol. 2
    # If we use `deep_titles`, the start reading section might include `Vol. 2`
    #   when the user hasn't started `Vol. 1` yet
    titles
      .select(&.load_percentage(username).== 0)
      .sample(ENTRIES_IN_HOME_SECTIONS)
      .shuffle!
  end

  def generate_thumbnails
    if thumbnail_ctx.current > 0
      Logger.debug "Thumbnail generation in progress"
      return
    end

    Logger.info "Starting thumbnail generation"
    entries = deep_titles.flat_map(&.deep_entries).reject &.err_msg
    thumbnail_ctx.total = entries.size
    thumbnail_ctx.current = 0

    # Report generation progress regularly
    spawn do
      loop do
        unless thumbnail_ctx.current == 0
          Logger.debug "Thumbnail generation progress: " \
                       "#{(thumbnail_ctx.progress * 100).round 1}%"
        end
        # Generation is completed. We reset the count to 0 to allow subsequent
        #   calls to the function, and break from the loop to stop the progress
        #   report fiber
        if thumbnail_ctx.progress.to_i == 1
          thumbnail_ctx.reset
          break
        end
        sleep 10.seconds
      end
    end

    entries.each do |e|
      unless e.get_thumbnail
        e.generate_thumbnail
        # Sleep after each generation to minimize the impact on disk IO
        #   and CPU
        sleep 1.seconds
      end
      thumbnail_ctx.increment
    end
    Logger.info "Thumbnail generation finished"
  end
end
