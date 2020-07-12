# Helper method used to sort chapters in a folder
# It respects the keywords like "Vol." and "Ch." in the filenames
# This sorting method was initially implemented in JS and done in the frontend.
#   see https://github.com/hkalexling/Mango/blob/
#     07100121ef15260b5a8e8da0e5948c993df574c5/public/js/sort-items.js#L15-L87

require "big"

private class Item
  getter index : Int32, numbers : Hash(String, BigDecimal)

  def initialize(@index, @numbers)
  end

  # Compare with another Item using keys
  def <=>(other : Item, keys : Array(String))
    keys.each do |key|
      if !@numbers.has_key?(key) && !other.numbers.has_key?(key)
        next
      elsif !@numbers.has_key? key
        return 1
      elsif !other.numbers.has_key? key
        return -1
      elsif @numbers[key] == other.numbers[key]
        next
      else
        return @numbers[key] <=> other.numbers[key]
      end
    end

    0
  end
end

private class KeyRange
  getter min : BigDecimal, max : BigDecimal, count : Int32

  def initialize(value : BigDecimal)
    @min = @max = value
    @count = 1
  end

  def update(value : BigDecimal)
    @min = value if value < @min
    @max = value if value > @max
    @count += 1
  end

  def range
    @max - @min
  end
end

def chapter_sort(in_ary : Array(String)) : Array(String)
  ary = in_ary.sort do |a, b|
    compare_numerically a, b
  end

  items = [] of Item
  keys = {} of String => KeyRange

  ary.each_with_index do |str, i|
    numbers = {} of String => BigDecimal

    str.scan /([^0-9\n\r\ ]*)[ ]*([0-9]*\.*[0-9]+)/ do |match|
      key = match[1]
      num = match[2].to_big_d

      numbers[key] = num

      if keys.has_key? key
        keys[key].update num
      else
        keys[key] = KeyRange.new num
      end
    end

    items << Item.new(i, numbers)
  end

  # Get the array of keys string and sort them
  sorted_keys = keys.keys
    # Only use keys that are present in over half of the strings
    .select do |key|
      keys[key].count >= ary.size / 2
    end
    .sort do |a_key, b_key|
      a = keys[a_key]
      b = keys[b_key]
      # Sort keys by the number of times they appear
      count_compare = b.count <=> a.count
      if count_compare == 0
        # Then sort by value range
        b.range <=> a.range
      else
        count_compare
      end
    end

  items
    .sort do |a, b|
      a.<=>(b, sorted_keys)
    end
    .map do |item|
      ary[item.index]
    end
end
