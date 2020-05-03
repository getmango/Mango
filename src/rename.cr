module Rename
  alias VHash = Hash(String, String)

  class Variable
    property id : String

    def initialize(@id)
    end

    def render(hash : VHash)
      hash[@id]? || ""
    end
  end

  class Pattern
    @ary = [] of Variable

    def push(var)
      @ary.push var
    end

    def render(hash : VHash)
      @ary.each do |v|
        if hash.has_key? v.id
          return v.render hash
        end
      end
      ""
    end
  end

  class Group
    @ary = [] of (Pattern | String)

    def push(var)
      @ary.push var
    end

    def render(hash : VHash)
      return "" if @ary.select(&.is_a? Pattern)
                     .any? &.as(Pattern).render(hash).empty?
      @ary.map do |e|
        if e.is_a? Pattern
          e.render hash
        else
          e
        end
      end.join
    end
  end

  class Rule
    ESCAPE = ['/']

    @ary = [] of (Group | String | Pattern)

    def initialize(str : String)
      parse! str
    rescue e
      raise "Failed to parse rename rule #{str}. Error: #{e}"
    end

    private def parse!(str : String)
      chars = [] of Char
      pattern : Pattern? = nil
      group : Group? = nil

      str.each_char_with_index do |char, i|
        if ['[', ']', '{', '}', '|'].includes?(char) && !chars.empty?
          string = chars.join
          if !pattern.nil?
            pattern.push Variable.new string.strip
          elsif !group.nil?
            group.push string
          else
            @ary.push string
          end
          chars = [] of Char
        end

        case char
        when '['
          if !group.nil? || !pattern.nil?
            raise "nested groups are not allowed"
          end
          group = Group.new
        when ']'
          if group.nil?
            raise "unmatched ] at position #{i}"
          end
          if !pattern.nil?
            raise "patterns (`{}`) should be closed before closing the group " \
                  "(`[]`)"
          end
          @ary.push group
          group = nil
        when '{'
          if !pattern.nil?
            raise "nested patterns are not allowed"
          end
          pattern = Pattern.new
        when '}'
          if pattern.nil?
            raise "unmatched } at position #{i}"
          end
          if !group.nil?
            group.push pattern
          else
            @ary.push pattern
          end
          pattern = nil
        when '|'
          if pattern.nil?
            chars.push char
          end
        else
          if ESCAPE.includes? char
            raise "the character #{char} at position #{i} is not allowed"
          end
          chars.push char
        end
      end

      unless chars.empty?
        @ary.push chars.join
      end
      if !pattern.nil?
        raise "unclosed pattern {"
      end
      if !group.nil?
        raise "unclosed group ["
      end
    end

    def render(hash : VHash)
      @ary.map do |e|
        if e.is_a? String
          e
        else
          e.render hash
        end
      end.join.strip
    end
  end
end
