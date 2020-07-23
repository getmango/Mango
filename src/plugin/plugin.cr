require "duktape/runtime"
require "myhtml"
require "http"
require "xml"

class Plugin
  class Error < ::Exception
  end

  class MetadataError < Error
  end

  class PluginException < Error
  end

  class SyntaxError < Error
  end

  struct Info
    {% for name in ["id", "title", "author", "version", "placeholder"] %}
      getter {{name.id}} = ""
    {% end %}
    getter wait_seconds : UInt64 = 0
    getter dir : String

    def initialize(@dir)
      info_path = File.join @dir, "info.json"

      unless File.exists? info_path
        raise MetadataError.new "File `info.json` not found in the " \
                                "plugin directory #{dir}"
      end

      json = JSON.parse File.read info_path

      begin
        {% for name in ["id", "title", "author", "version", "placeholder"] %}
          @{{name.id}} = json[{{name}}].as_s
        {% end %}
        @wait_seconds = json["wait_seconds"].as_i.to_u64

        unless @id.alphanumeric_underscore?
          raise "Plugin ID can only contain alphanumeric characters and " \
                "underscores"
        end
      rescue e
        raise MetadataError.new "Failed to retrieve metadata from plugin " \
                                "at #{@dir}. Error: #{e.message}"
      end
    end
  end

  struct State
    @hash = {} of String => String

    def initialize(@path : String)
      unless File.exists? @path
        save
      end

      json = JSON.parse File.read @path
      json.as_h.each do |k, v|
        @hash[k] = v.as_s
      end
    end

    def []?(key)
      @hash[key]?
    end

    def []=(key, val : String)
      @hash[key] = val
    end

    def save
      File.write @path, @hash.to_pretty_json
    end
  end

  @@info_ary = [] of Info
  @info : Info?

  getter js_path = ""
  getter state_path = ""

  def self.build_info_ary
    return unless @@info_ary.empty?

    dir = Config.current.plugin_path
    Dir.mkdir_p dir unless Dir.exists? dir

    Dir.each_child dir do |f|
      path = File.join dir, f
      next unless File.directory? path

      begin
        @@info_ary << Info.new path
      rescue e : MetadataError
        Logger.warn e
      end
    end
  end

  def self.list
    self.build_info_ary

    @@info_ary.map &.title
  end

  def info
    @info.not_nil!
  end

  def self.new_from_id(id : String)
    self.build_info_ary

    info = @@info_ary.find { |i| i.id == id }
    raise Error.new "Plugin with id #{id} not found" unless info
    self.new info.title
  end

  def initialize(title : String)
    Plugin.build_info_ary

    @info = @@info_ary.find { |i| i.title == title }
    if @info.nil?
      raise Error.new "Plugin with title #{title} not found"
    end

    @js_path = File.join info.dir, "main.js"
    @state_path = File.join info.dir, "state.json"

    unless File.exists? @js_path
      raise Error.new "Plugin script not found at #{@js_path}"
    end

    @rt = Duktape::Runtime.new do |sbx|
      sbx.push_global_object

      sbx.push_pointer @state_path.as(Void*)
      path = sbx.require_pointer(-1).as String
      sbx.pop
      sbx.push_string path
      sbx.put_prop_string -2, "state_path"

      def_helper_functions sbx
    end

    eval File.read @js_path
  end

  macro check_fields(ary)
    {% for field in ary %}
      unless json[{{field}}]?
        raise "Field `{{field.id}}` is missing from the function outputs"
      end
    {% end %}
  end

  def search(query : String)
    json = eval_json "search('#{query}')"
    begin
      check_fields ["title", "chapters"]

      ary = json["chapters"].as_a
      ary.each do |obj|
        id = obj["id"]?
        raise "Field `id` missing from `search` outputs" if id.nil?

        unless id.to_s.alphanumeric_underscore?
          raise "The `id` field can only contain alphanumeric characters " \
                "and underscores"
        end

        title = obj["title"]?
        raise "Field `title` missing from `search` outputs" if title.nil?
      end
    rescue e
      raise Error.new e.message
    end
    json
  end

  def select_chapter(id : String)
    json = eval_json "selectChapter('#{id}')"
    begin
      check_fields ["title", "pages"]

      if json["title"].to_s.empty?
        raise "The `title` field of the chapter can not be empty"
      end
    rescue e
      raise Error.new e.message
    end
    json
  end

  def next_page
    json = eval_json "nextPage()"
    return if json.size == 0
    begin
      check_fields ["filename", "url"]
    rescue e
      raise Error.new e.message
    end
    json
  end

  private def eval(str)
    @rt.eval str
  rescue e : Duktape::SyntaxError
    raise SyntaxError.new e.message
  rescue e : Duktape::Error
    raise Error.new e.message
  end

  private def eval_json(str)
    JSON.parse eval(str).as String
  end

  private def def_helper_functions(sbx)
    sbx.push_object

    sbx.push_proc LibDUK::VARARGS do |ptr|
      env = Duktape::Sandbox.new ptr
      url = env.require_string 0

      headers = HTTP::Headers.new

      if env.get_top == 2
        env.enum 1, LibDUK::Enum::OwnPropertiesOnly
        while env.next -1, true
          k = env.require_string -2
          v = env.require_string -1
          headers.add k, v
          env.pop_2
        end
      end

      res = HTTP::Client.get url, headers
      body = res.body

      env.push_string body
      env.call_success
    end
    sbx.put_prop_string -2, "get"

    sbx.push_proc 2 do |ptr|
      env = Duktape::Sandbox.new ptr
      html = env.require_string 0
      selector = env.require_string 1

      myhtml = Myhtml::Parser.new html
      json = myhtml.css(selector).map(&.to_html).to_a.to_json

      env.push_string json
      env.call_success
    end
    sbx.put_prop_string -2, "css"

    sbx.push_proc 1 do |ptr|
      env = Duktape::Sandbox.new ptr
      html = env.require_string 0

      str = XML.parse(html).inner_text

      env.push_string str
      env.call_success
    end
    sbx.put_prop_string -2, "text"

    sbx.push_proc 2 do |ptr|
      env = Duktape::Sandbox.new ptr
      html = env.require_string 0
      name = env.require_string 1

      begin
        attr = XML.parse(html).first_element_child.not_nil![name]
        env.push_string attr
      rescue
        env.push_undefined
      end

      env.call_success
    end
    sbx.put_prop_string -2, "attribute"

    sbx.push_proc 1 do |ptr|
      env = Duktape::Sandbox.new ptr
      msg = env.require_string 0
      env.call_success

      raise PluginException.new msg
    end
    sbx.put_prop_string -2, "raise"

    sbx.push_proc LibDUK::VARARGS do |ptr|
      env = Duktape::Sandbox.new ptr
      key = env.require_string 0

      env.get_global_string "state_path"
      state_path = env.require_string -1
      env.pop
      state = State.new state_path

      if env.get_top == 2
        val = env.require_string 1
        state[key] = val
        state.save
      else
        val = state[key]?
        if val
          env.push_string val
        else
          env.push_undefined
        end
      end

      env.call_success
    end
    sbx.put_prop_string -2, "state"

    sbx.put_prop_string -2, "mango"
  end
end
