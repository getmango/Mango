require "digest"

require "./entry"
require "./types"

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

alias CacheableType = Array(Entry) | String | Tuple(String, Int32)
alias CacheEntryType = SortedEntriesCacheEntry |
                       CacheEntry(String, String) |
                       CacheEntry(Tuple(String, Int32), Tuple(String, Int32))

def generate_cache_entry(key : String, value : CacheableType)
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

  def self.enabled
    Config.current.sorted_entries_cache_enable
  end

  def self.init
    cache_size = Config.current.sorted_entries_cache_size_mbs
    @@limit = Int128.new cache_size * 1024 * 1024 if enabled
  end

  def self.get(key : String)
    return unless enabled
    entry = @@cache[key]?
    Logger.debug "LRUCache Cache Hit! #{key}" unless entry.nil?
    Logger.debug "LRUCache Cache Miss #{key}" if entry.nil?
    return entry.value unless entry.nil?
  end

  def self.set(cache_entry : CacheEntryType)
    return unless enabled
    key = cache_entry.key
    @@cache[key] = cache_entry
    Logger.debug "LRUCache Cached #{key}"
    remove_victim_cache
  end

  def self.invalidate(key : String)
    return unless enabled
    @@cache.delete key
  end

  def self.print
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
