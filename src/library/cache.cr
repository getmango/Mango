require "digest"

require "./entry"
require "./title"
require "./types"

# Base class for an entry in the LRU cache.
# There are two ways to use it:
#   1. Use it as it is by instantiating with the appropriate `SaveT` and
#     `ReturnT`. Note that in this case, `SaveT` and `ReturnT` must be the
#     same type. That is, the input value will be stored as it is without
#     any transformation.
#   2. You can also subclass it and provide custom implementations for
#     `to_save_t` and `to_return_t`. This allows you to transform and store
#     the input value to a different type. See `SortedEntriesCacheEntry` as
#     an example.
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
    ids_to_entries value
  end

  private def self.ids_to_entries(ids : Array(String))
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
    entries_sig = Digest::SHA1.hexdigest (entries.map &.id).to_s
    user_context = opt && opt.method == SortMethod::Progress ? username : ""
    sig = Digest::SHA1.hexdigest(book_id + entries_sig + user_context +
                                 (opt ? opt.to_tuple.to_s : "nil"))
    "#{sig}:sorted_entries"
  end
end

class SortedTitlesCacheEntry < CacheEntry(Array(String), Array(Title))
  def self.to_save_t(value : Array(Title))
    value.map &.id
  end

  def self.to_return_t(value : Array(String))
    value.map { |title_id| Library.default.title_hash[title_id].not_nil! }
  end

  def instance_size
    instance_sizeof(SortedTitlesCacheEntry) +   # sizeof itself
      instance_sizeof(String) + @key.bytesize + # allocated memory for @key
      @value.size * (instance_sizeof(String) + sizeof(String)) +
      @value.sum(&.bytesize) # elements in Array(String)
  end

  def self.gen_key(username : String, titles : Array(Title), opt : SortOptions?)
    titles_sig = Digest::SHA1.hexdigest (titles.map &.id).to_s
    user_context = opt && opt.method == SortMethod::Progress ? username : ""
    sig = Digest::SHA1.hexdigest(titles_sig + user_context +
                                 (opt ? opt.to_tuple.to_s : "nil"))
    "#{sig}:sorted_titles"
  end
end

class String
  def instance_size
    instance_sizeof(String) + bytesize
  end
end

struct Tuple(*T)
  def instance_size
    sizeof(T) + # total size of non-reference types
      self.sum do |e|
        next 0 unless e.is_a? Reference
        if e.responds_to? :instance_size
          e.instance_size
        else
          instance_sizeof(typeof(e))
        end
      end
  end
end

alias CacheableType = Array(Entry) | Array(Title) | String |
                      Tuple(String, Int32)
alias CacheEntryType = SortedEntriesCacheEntry |
                       SortedTitlesCacheEntry |
                       CacheEntry(String, String) |
                       CacheEntry(Tuple(String, Int32), Tuple(String, Int32))

def generate_cache_entry(key : String, value : CacheableType)
  if value.is_a? Array(Entry)
    SortedEntriesCacheEntry.new key, value
  elsif value.is_a? Array(Title)
    SortedTitlesCacheEntry.new key, value
  else
    CacheEntry(typeof(value), typeof(value)).new key, value
  end
end

# LRU Cache
class LRUCache
  @@limit : Int128 = Int128.new 0
  @@should_log = true
  # key => entry
  @@cache = {} of String => CacheEntryType

  def self.enabled
    Config.current.cache_enabled
  end

  def self.init
    cache_size = Config.current.cache_size_mbs
    @@limit = Int128.new cache_size * 1024 * 1024 if enabled
    @@should_log = Config.current.cache_log_enabled
  end

  def self.get(key : String)
    return unless enabled
    entry = @@cache[key]?
    if @@should_log
      Logger.debug "LRUCache #{entry.nil? ? "miss" : "hit"} #{key}"
    end
    return entry.value unless entry.nil?
  end

  def self.set(cache_entry : CacheEntryType)
    return unless enabled
    key = cache_entry.key
    @@cache[key] = cache_entry
    Logger.debug "LRUCache cached #{key}" if @@should_log
    remove_least_recent_access
  end

  def self.invalidate(key : String)
    return unless enabled
    @@cache.delete key
  end

  def self.print
    return unless @@should_log
    sum = @@cache.sum { |_, entry| entry.instance_size }
    Logger.debug "---- LRU Cache ----"
    Logger.debug "Size: #{sum} Bytes"
    Logger.debug "List:"
    @@cache.each do |k, v|
      Logger.debug "#{k} | #{v.atime} | #{v.instance_size}"
    end
    Logger.debug "-------------------"
  end

  private def self.is_cache_full
    sum = @@cache.sum { |_, entry| entry.instance_size }
    sum > @@limit
  end

  private def self.remove_least_recent_access
    if @@should_log && is_cache_full
      Logger.debug "Removing entries from LRUCache"
    end
    while is_cache_full && @@cache.size > 0
      min_tuple = @@cache.min_by { |_, entry| entry.atime }
      min_key = min_tuple[0]
      min_entry = min_tuple[1]

      Logger.debug "  \
        Target: #{min_key}, \
        Last Access Time: #{min_entry.atime}" if @@should_log
      invalidate min_key
    end
  end
end
