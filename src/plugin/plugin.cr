require "duktape/runtime"
require "myhtml"
require "xml"

require "./subscriptions"

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
    include JSON::Serializable

    {% for name in ["id", "title", "placeholder"] %}
      getter {{name.id}} = ""
    {% end %}
    getter wait_seconds = 0u64
    getter version = 0u64
    getter settings = {} of String => String?
    getter dir : String

    @[JSON::Field(ignore: true)]
    @json : JSON::Any

    def initialize(@dir)
      info_path = File.join @dir, "info.json"

      unless File.exists? info_path
        raise MetadataError.new "File `info.json` not found in the " \
                                "plugin directory #{dir}"
      end

      @json = JSON.parse File.read info_path

      begin
        {% for name in ["id", "title", "placeholder"] %}
          @{{name.id}} = @json[{{name}}].as_s
        {% end %}
        @wait_seconds = @json["wait_seconds"].as_i.to_u64
        @version = @json["api_version"]?.try(&.as_i.to_u64) || 1u64

        if @version > 1 && (settings_hash = @json["settings"]?.try &.as_h?)
          settings_hash.each do |k, v|
            unless str_value = v.as_s?
              raise "The settings object can only contain strings or null"
            end
            @settings[k] = str_value
          end
        end

        unless @id.alphanumeric_underscore?
          raise "Plugin ID can only contain alphanumeric characters and " \
                "underscores"
        end
      rescue e
        raise MetadataError.new "Failed to retrieve metadata from plugin " \
                                "at #{@dir}. Error: #{e.message}"
      end
    end

    def each(&block : String, JSON::Any -> _)
      @json.as_h.each &block
    end
  end

  struct Storage
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
  getter storage_path = ""

  def self.build_info_ary(dir : String? = nil)
    @@info_ary.clear
    dir ||= Config.current.plugin_path

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
    @@info_ary.map do |m|
      {id: m.id, title: m.title}
    end
  end

  def info
    @info.not_nil!
  end

  def subscribe(subscription : Subscription)
    list = SubscriptionList.new info.dir
    list << subscription
    list.save
  end

  def list_subscriptions
    SubscriptionList.new(info.dir).ary
  end

  def list_subscriptions_raw
    SubscriptionList.new(info.dir)
  end

  def unsubscribe(id : String)
    list = SubscriptionList.new info.dir
    list.reject! &.id.== id
    list.save
  end

  def check_subscription(id : String)
    list = list_subscriptions_raw
    sub = list.find &.id.== id
    Plugin::Updater.default.check_subscription self, sub.not_nil!
    list.save
  end

  def initialize(id : String, dir : String? = nil)
    Plugin.build_info_ary dir

    @info = @@info_ary.find &.id.== id
    if @info.nil?
      raise Error.new "Plugin with ID #{id} not found"
    end

    @js_path = File.join info.dir, "index.js"
    @storage_path = File.join info.dir, "storage.json"

    unless File.exists? @js_path
      raise Error.new "Plugin script not found at #{@js_path}"
    end

    @rt = Duktape::Runtime.new do |sbx|
      sbx.push_global_object

      sbx.push_pointer @storage_path.as(Void*)
      path = sbx.require_pointer(-1).as String
      sbx.pop
      sbx.push_string path
      sbx.put_prop_string -2, "storage_path"

      sbx.push_pointer info.dir.as(Void*)
      path = sbx.require_pointer(-1).as String
      sbx.pop
      sbx.push_string path
      sbx.put_prop_string -2, "info_dir"

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

  def assert_manga_type(obj : JSON::Any)
    obj["id"].as_s && obj["title"].as_s
  rescue e
    raise Error.new "Missing required fields in the Manga type"
  end

  def assert_chapter_type(obj : JSON::Any)
    obj["id"].as_s && obj["title"].as_s && obj["pages"].as_i &&
      obj["manga_title"].as_s
  rescue e
    raise Error.new "Missing required fields in the Chapter type"
  end

  def assert_page_type(obj : JSON::Any)
    obj["url"].as_s && obj["filename"].as_s
  rescue e
    raise Error.new "Missing required fields in the Page type"
  end

  def can_subscribe? : Bool
    info.version > 1 && eval_exists?("newChapters")
  end

  def search_manga(query : String)
    if info.version == 1
      raise Error.new "Manga searching is only available for plugins " \
                      "targeting API v2 or above"
    end
    json = eval_json "searchManga('#{query}')"
    begin
      json.as_a.each do |obj|
        assert_manga_type obj
      end
    rescue e
      raise Error.new e.message
    end
    json
  end

  def list_chapters(query : String)
    json = eval_json "listChapters('#{query}')"
    begin
      if info.version > 1
        # Since v2, listChapters returns an array
        json.as_a.each do |obj|
          assert_chapter_type obj
        end
      else
        check_fields ["title", "chapters"]

        ary = json["chapters"].as_a
        ary.each do |obj|
          id = obj["id"]?
          raise "Field `id` missing from `listChapters` outputs" if id.nil?

          unless id.to_s.alphanumeric_underscore?
            raise "The `id` field can only contain alphanumeric characters " \
                  "and underscores"
          end

          title = obj["title"]?
          if title.nil?
            raise "Field `title` missing from `listChapters` outputs"
          end
        end
      end
    rescue e
      raise Error.new e.message
    end
    json
  end

  def select_chapter(id : String)
    json = eval_json "selectChapter('#{id}')"
    begin
      if info.version > 1
        assert_chapter_type json
      else
        check_fields ["title", "pages"]

        if json["title"].to_s.empty?
          raise "The `title` field of the chapter can not be empty"
        end
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
      assert_page_type json
    rescue e
      raise Error.new e.message
    end
    json
  end

  def new_chapters(manga_id : String, after : Int64)
    # Converting standard timestamp to milliseconds so plugins can easily do
    #   `new Date(ms_timestamp)` in JS.
    json = eval_json "newChapters('#{manga_id}', #{after * 1000})"
    begin
      json.as_a.each do |obj|
        assert_chapter_type obj
      end
    rescue e
      raise Error.new e.message
    end
    json
  end

  def eval(str)
    @rt.eval str
  rescue e : Duktape::SyntaxError
    raise SyntaxError.new e.message
  rescue e : Duktape::Error
    raise Error.new e.message
  end

  private def eval_json(str)
    JSON.parse eval(str).as String
  end

  private def eval_exists?(str) : Bool
    @rt.eval str
    true
  rescue e : Duktape::ReferenceError
    false
  rescue e : Duktape::Error
    raise Error.new e.message
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
          key = env.require_string -2
          val = env.require_string -1
          headers.add key, val
          env.pop_2
        end
      end

      res = HTTP::Client.get url, headers

      env.push_object

      env.push_int res.status_code
      env.put_prop_string -2, "status_code"

      env.push_string res.body
      env.put_prop_string -2, "body"

      env.push_object
      res.headers.each do |k, v|
        if v.size == 1
          env.push_string v[0]
        else
          env.push_string v.join ","
        end
        env.put_prop_string -2, k
      end
      env.put_prop_string -2, "headers"

      env.call_success
    end
    sbx.put_prop_string -2, "get"

    sbx.push_proc LibDUK::VARARGS do |ptr|
      env = Duktape::Sandbox.new ptr
      url = env.require_string 0
      body = env.require_string 1

      headers = HTTP::Headers.new

      if env.get_top == 3
        env.enum 2, LibDUK::Enum::OwnPropertiesOnly
        while env.next -1, true
          key = env.require_string -2
          val = env.require_string -1
          headers.add key, val
          env.pop_2
        end
      end

      res = HTTP::Client.post url, headers, body

      env.push_object

      env.push_int res.status_code
      env.put_prop_string -2, "status_code"

      env.push_string res.body
      env.put_prop_string -2, "body"

      env.push_object
      res.headers.each do |k, v|
        if v.size == 1
          env.push_string v[0]
        else
          env.push_string v.join ","
        end
        env.put_prop_string -2, k
      end
      env.put_prop_string -2, "headers"

      env.call_success
    end
    sbx.put_prop_string -2, "post"

    sbx.push_proc 2 do |ptr|
      env = Duktape::Sandbox.new ptr
      html = env.require_string 0
      selector = env.require_string 1

      myhtml = Myhtml::Parser.new html
      ary = myhtml.css(selector).map(&.to_html).to_a

      ary_idx = env.push_array
      ary.each_with_index do |str, i|
        env.push_string str
        env.put_prop_index ary_idx, i.to_u32
      end

      env.call_success
    end
    sbx.put_prop_string -2, "css"

    sbx.push_proc 1 do |ptr|
      env = Duktape::Sandbox.new ptr
      html = env.require_string 0

      begin
        parser = Myhtml::Parser.new html
        str = parser.body!.children.first.inner_text

        env.push_string str
      rescue
        env.push_string ""
      end

      env.call_success
    end
    sbx.put_prop_string -2, "text"

    sbx.push_proc 2 do |ptr|
      env = Duktape::Sandbox.new ptr
      html = env.require_string 0
      name = env.require_string 1

      begin
        parser = Myhtml::Parser.new html
        attr = parser.body!.children.first.attribute_by name
        env.push_string attr.not_nil!
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

      env.get_global_string "storage_path"
      storage_path = env.require_string -1
      env.pop
      storage = Storage.new storage_path

      if env.get_top == 2
        val = env.require_string 1
        storage[key] = val
        storage.save
      else
        val = storage[key]?
        if val
          env.push_string val
        else
          env.push_undefined
        end
      end

      env.call_success
    end
    sbx.put_prop_string -2, "storage"

    if info.version > 1
      sbx.push_proc 1 do |ptr|
        env = Duktape::Sandbox.new ptr
        key = env.require_string 0

        env.get_global_string "info_dir"
        info_dir = env.require_string -1
        env.pop
        info = Info.new info_dir

        if value = info.settings[key]?
          env.push_string value
        else
          env.push_undefined
        end

        env.call_success
      end
      sbx.put_prop_string -2, "settings"
    end

    sbx.put_prop_string -2, "mango"
  end
end
