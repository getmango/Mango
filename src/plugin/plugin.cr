require "duktape/runtime"
require "myhtml"
require "http"

class Plugin
  class Error < ::Exception
  end

  class MetadataError < Error
  end

  class PluginException < Error
  end

  class SyntaxError < Error
  end

  {% for name in ["id", "title", "author", "version", "placeholder"] %}
    getter {{name.id}} = ""
  {% end %}
  getter wait_seconds : UInt64 = 0

  def self.list
    dir = Config.current.plugin_path
    unless Dir.exists? dir
      Dir.mkdir_p dir
    end
    Dir.children(dir)
      .select do |f|
        fp = File.join dir, f
        File.file?(fp) && File.extname(fp) == ".js"
      end
      .map do |f|
        File.basename f, ".js"
      end
  end

  def initialize(@path : String)
    @rt = Duktape::Runtime.new do |sbx|
      sbx.push_global_object

      sbx.del_prop_string -1, "print"
      sbx.del_prop_string -1, "alert"
      sbx.del_prop_string -1, "console"

      def_helper_functions sbx
    end

    eval File.read @path

    begin
      data = eval_json "metadata"
      {% for name in ["id", "title", "author", "version", "placeholder"] %}
        @{{name.id}} = data[{{name}}].as_s
      {% end %}
      @wait_seconds = data["wait_seconds"].as_i.to_u64
    rescue e
      raise MetadataError.new "Failed to retrieve metadata from plugin " \
                              "at #{@path}. Error: #{e.message}"
    end
  end

  def search(query : String)
    json = eval_json "search('#{query}')"
    begin
      ary = json.as_a
      ary.each do |obj|
        id = obj["id"]?
        raise "Field `id` missing from `search` outputs" if id.nil?

        unless id.to_s.chars.all? &.number?
          raise "The `id` values must be numeric" unless id
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
      {% for field in ["title", "pages"] %}
        unless json[{{field}}]?
          raise "Field `{{field.id}}` is missing from the " \
                "`selectChapter` outputs"
        end
      {% end %}
    rescue e
      raise Error.new e.message
    end
    json
  end

  def next_page
    json = eval_json "nextPage()"
    return if json.size == 0
    begin
      {% for field in ["filename", "url"] %}
        unless json[{{field}}]?
          raise "Field `{{field.id}}` is missing from the " \
                "`nextPage` outputs"
        end
      {% end %}
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

      myhtml = Myhtml::Parser.new html
      root = myhtml.root

      str = ""
      str = root.inner_text if root

      env.push_string str
      env.call_success
    end
    sbx.put_prop_string -2, "innerText"

    sbx.push_proc 1 do |ptr|
      env = Duktape::Sandbox.new ptr
      msg = env.require_string 0
      env.call_success

      raise PluginException.new msg
    end
    sbx.put_prop_string -2, "raise"

    sbx.put_prop_string -2, "mango"
  end
end
