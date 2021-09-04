require "digest"

require "./entry"

class InfoCache
  alias ProgressCache = Tuple(String, Int32)

  def self.clear
    clear_cover_url
    clear_progress_cache
    clear_sort_opt
  end

  def self.clean
    clean_cover_url
    clean_progress_cache
    clean_sort_opt
  end

  # item id => cover_url
  @@cached_cover_url = {} of String => String
  @@cached_cover_url_previous = {} of String => String # item id => cover_url

  def self.set_cover_url(id : String, cover_url : String)
    @@cached_cover_url[id] = cover_url
  end

  def self.get_cover_url(id : String)
    @@cached_cover_url[id]?
  end

  def self.invalidate_cover_url(id : String)
    @@cached_cover_url.delete id
  end

  def self.move_cover_url(id : String)
    if @@cached_cover_url_previous[id]?
      @@cached_cover_url[id] = @@cached_cover_url_previous[id]
    end
  end

  private def self.clear_cover_url
    @@cached_cover_url_previous = @@cached_cover_url
    @@cached_cover_url = {} of String => String
  end

  private def self.clean_cover_url
    @@cached_cover_url_previous = {} of String => String
  end

  # book.id:username => {signature, sum}
  @@progress_cache = {} of String => ProgressCache
  # book.id => username => {signature, sum}
  @@progress_cache_previous = {} of String => Hash(String, ProgressCache)

  def self.set_progress_cache(book_id : String, username : String,
                              entries : Array(Entry), sum : Int32)
    progress_cache_id = "#{book_id}:#{username}"
    progress_cache_sig = Digest::SHA1.hexdigest (entries.map &.id).to_s
    @@progress_cache[progress_cache_id] = {progress_cache_sig, sum}
    Logger.debug "Progress Cached #{progress_cache_id}"
  end

  def self.get_progress_cache(book_id : String, username : String,
                              entries : Array(Entry))
    progress_cache_id = "#{book_id}:#{username}"
    progress_cache_sig = Digest::SHA1.hexdigest (entries.map &.id).to_s
    cached = @@progress_cache[progress_cache_id]?
    if cached && cached[0] == progress_cache_sig
      Logger.debug "Progress Cache Hit! #{progress_cache_id}"
      return cached[1]
    end
  end

  def self.invalidate_progress_cache(book_id : String, username : String)
    progress_cache_id = "#{book_id}:#{username}"
    if @@progress_cache[progress_cache_id]?
      @@progress_cache.delete progress_cache_id
      Logger.debug "Progress Invalidate Cache #{progress_cache_id}"
    end
  end

  def self.move_progress_cache(book_id : String)
    if @@progress_cache_previous[book_id]?
      @@progress_cache_previous[book_id].each do |username, cached|
        id = "#{book_id}:#{username}"
        unless @@progress_cache[id]?
          # It would be invalidated when entries changed
          @@progress_cache[id] = cached
        end
      end
    end
  end

  private def self.clear_progress_cache
    @@progress_cache_previous = {} of String => Hash(String, ProgressCache)
    @@progress_cache.each do |id, cached|
      splitted = id.split(':', 2)
      book_id = splitted[0]
      username = splitted[1]
      unless @@progress_cache_previous[book_id]?
        @@progress_cache_previous[book_id] = {} of String => ProgressCache
      end

      @@progress_cache_previous[book_id][username] = cached
    end
    @@progress_cache = {} of String => ProgressCache
  end

  private def self.clean_progress_cache
    @@progress_cache_previous = {} of String => Hash(String, ProgressCache)
  end

  # book.dir:username => SortOptions
  @@cached_sort_opt = {} of String => SortOptions
  @@cached_sort_opt_previous = {} of String => Hash(String, SortOptions)

  def self.set_sort_opt(dir : String, username : String, sort_opt : SortOptions)
    id = "#{dir}:#{username}"
    @@cached_sort_opt[id] = sort_opt
  end

  def self.get_sort_opt(dir : String, username : String)
    id = "#{dir}:#{username}"
    @@cached_sort_opt[id]?
  end

  def self.invalidate_sort_opt(dir : String, username : String)
    id = "#{dir}:#{username}"
    @@cached_sort_opt.delete id
  end

  def self.move_sort_opt(dir : String)
    if @@cached_sort_opt_previous[dir]?
      @@cached_sort_opt_previous[dir].each do |username, cached|
        id = "#{dir}:#{username}"
        unless @@cached_sort_opt[id]?
          @@cached_sort_opt[id] = cached
        end
      end
    end
  end

  private def self.clear_sort_opt
    @@cached_sort_opt_previous = {} of String => Hash(String, SortOptions)
    @@cached_sort_opt.each do |id, cached|
      splitted = id.split(':', 2)
      book_dir = splitted[0]
      username = splitted[1]
      unless @@cached_sort_opt_previous[book_dir]?
        @@cached_sort_opt_previous[book_dir] = {} of String => SortOptions
      end
      @@cached_sort_opt_previous[book_dir][username] = cached
    end
    @@cached_sort_opt = {} of String => SortOptions
  end

  private def self.clean_sort_opt
    @@cached_sort_opt_previous = {} of String => Hash(String, SortOptions)
  end
end

private class CacheEntry(SaveT, ReturnT)
  getter key : String, atime : Time

  @value : SaveT

  def initialize(@key : String, value : ReturnT)
    @atime = @ctime = Time.utc
    @value = self.class.to_save_t value
  end

  def value
    @atime = Time.utc
    self.class.to_return_t @value
  end

  def self.to_save_t(value : ReturnT)
    value
  end

  def self.to_return_t(value : SaveT)
    value
  end

  def instance_size
    instance_sizeof(CacheEntry(SaveT, ReturnT)) + # sizeof itself
      instance_sizeof(String) + @key.bytesize +   # allocated memory for @key
      @value.instance_size
  end
end

class SortedEntriesCacheEntry < CacheEntry(Array(String), Array(Entry))
  def self.to_save_t(value : Array(Entry))
    value.map &.id
  end

  def self.to_return_t(value : Array(String))
    ids2entries value
  end

  private def self.ids2entries(ids : Array(String))
    e_map = Library.default.deep_entries.to_h { |entry| {entry.id, entry} }
    entries = [] of Entry
    begin
      ids.each do |id|
        entries << e_map[id]
      end
      return entries if ids.size == entries.size
    rescue
    end
  end

  def instance_size
    instance_sizeof(SortedEntriesCacheEntry) +  # sizeof itself
      instance_sizeof(String) + @key.bytesize + # allocated memory for @key
      @value.size * (instance_sizeof(String) + sizeof(String)) +
      @value.sum(&.bytesize) # elements in Array(String)
  end

  def self.gen_key(book_id : String, username : String,
                   entries : Array(Entry), opt : SortOptions?)
    sig = Digest::SHA1.hexdigest (entries.map &.id).to_s
    user_context = opt && opt.method == SortMethod::Progress ? username : ""
    Digest::SHA1.hexdigest (book_id + sig + user_context +
                            (opt ? opt.to_tuple.to_s : "nil"))
  end
end

alias CacheEntryType = SortedEntriesCacheEntry

def generate_cache_entry(key : String, value : Array(Entry) | Int32 | String)
  if value.is_a? Array(Entry)
    SortedEntriesCacheEntry.new key, value
  else
    CacheEntry(typeof(value), typeof(value)).new key, value
  end
end

# LRU Cache
class LRUCache
  @@limit : Int128 = Int128.new 0
  # key => entry
  @@cache = {} of String => CacheEntryType

  def self.init
    enabled = Config.current.sorted_entries_cache_enable
    cache_size = Config.current.sorted_entries_cache_size_mbs
    @@limit = Int128.new cache_size * 1024 * 1024 if enabled
  end

  def self.get(key : String)
    entry = @@cache[key]?
    Logger.debug "LRUCache Cache Hit! #{key}" unless entry.nil?
    Logger.debug "LRUCache Cache Miss #{key}" if entry.nil?
    return entry.value unless entry.nil?
  end

  def self.set(cache_entry : CacheEntryType)
    key = cache_entry.key
    @@cache[key] = cache_entry
    Logger.debug "LRUCache Cached #{key}"
    remove_victim_cache
  end

  def self.invalidate(key : String)
    @@cache.delete key
  end

  def self.print
    sum = @@cache.sum { |_, entry| entry.instance_size }
    Logger.debug "---- LRU Cache ----"
    Logger.debug "Size: #{sum} Bytes"
    Logger.debug "List:"
    @@cache.each { |k, v| Logger.debug "#{k} | #{v.atime}" }
    Logger.debug "-------------------"
  end

  private def self.is_cache_full
    sum = @@cache.sum { |_, entry| entry.instance_size }
    sum > @@limit
  end

  private def self.remove_victim_cache
    while is_cache_full && @@cache.size > 0
      Logger.debug "LRUCache Cache Full! Remove LRU"
      min = @@cache.min_by? { |_, entry| entry.atime }
      Logger.debug "  \
        Target: #{min[0]}, \
        Last Access Time: #{min[1].atime}" if min
      invalidate min[0] if min
    end
  end
end
