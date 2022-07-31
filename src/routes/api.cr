require "../upload"
require "koa"
require "digest"

struct APIRouter
  @@api_json : String?

  API_VERSION = "0.1.0"

  macro s(fields)
    {
      {% for field in fields %}
        {{field}} => String,
      {% end %}
    }
  end

  def initialize
    Koa.init "Mango API", version: API_VERSION, desc: <<-MD
    # A Word of Caution

    This API was designed for internal use only, and the design doesn't comply with the resources convention of a RESTful API. Because of this, most of the API endpoints listed here will soon be updated and removed in future versions of Mango, so use them at your own risk!

    # Authentication

    All endpoints except `/api/login` require authentication. After logging in, your session ID would be stored as a cookie named `mango-sessid-#{Config.current.port}`, which can be used to authenticate the API access. Note that all admin API endpoints (`/api/admin/...`) require the logged-in user to have admin access.

    # Terminologies

    - Entry: An entry is a `cbz`/`cbr` file in your library. Depending on how you organize your manga collection, an entry can contain a chapter, a volume or even an entire manga.
    - Title: A title contains a list of entries and optionally some sub-titles. For example, you can have a title to store a manga, and it contains a list of sub-titles representing the volumes in the manga. Each sub-title would then contain a list of entries representing the chapters in the volume.
    - Library: The library is a collection of top-level titles, and it does not contain entries (though the titles do). A Mango instance can only have one library.
    MD

    Koa.cookie_auth "cookie", "mango-sessid-#{Config.current.port}"
    Koa.define_tag "admin", desc: <<-MD
      These are the admin endpoints only accessible for users with admin access. A non-admin user will get HTTP 403 when calling the endpoints.
    MD

    Koa.schema "entry", {
      "pages" => Int32,
      "mtime" => Int64,
    }.merge(s %w(zip_path path title size id title_id display_name cover_url)),
      desc: "An entry in a book"

    Koa.schema "title", {
      "mtime"   => Int64,
      "entries" => ["entry"],
      "titles"  => ["title"],
      "parents" => [{
        "title" => String,
        "id"    => String,
      }],
      "title_percentages" => [Float64?],
      "entry_percentages" => [Float64?],
    }.merge(s %w(dir title id display_name cover_url)),
      desc: "A manga title (a collection of entries and sub-titles)"

    Koa.schema "result", {
      "success" => Bool,
      "error"   => String?,
    }

    Koa.schema "filter", {
      "key"   => String,
      "type"  => String,
      "value" => String | Int32 | Int64 | Float32,
    }

    Koa.schema "subscription", {
      "id"           => String,
      "plugin_id"    => String,
      "manga_id"     => String,
      "manga_title"  => String,
      "name"         => String,
      "created_at"   => Int64,
      "last_checked" => Int64,
      "filters"      => ["filter"],
    }

    Koa.describe "Authenticates a user", <<-MD
    After successful login, the cookie `mango-sessid-#{Config.current.port}` will contain a valid session ID that can be used for subsequent requests
    MD
    Koa.body schema: {
      "username" => String,
      "password" => String,
    }
    Koa.response 200, schema: {
      "success"    => Bool,
      "error"      => String?,
      "session_id" => String?,
      "is_admin"   => Bool?,
    }
    Koa.tag "users"
    post "/api/login" do |env|
      begin
        username = env.params.json["username"].as String
        password = env.params.json["password"].as String
        token = Storage.default.verify_user(username, password).not_nil!

        env.session.string "token", token
        send_json env, {
          "success"    => true,
          "session_id" => env.session.id,
          "is_admin"   => Storage.default.username_is_admin username,
        }.to_json
      rescue e
        Logger.error e
        env.response.status_code = 403
        send_json env, {
          "success" => false,
          "error"   => e.message,
        }.to_json
      end
    end

    Koa.describe "Returns a page in a manga entry"
    Koa.path "tid", desc: "Title ID"
    Koa.path "eid", desc: "Entry ID"
    Koa.path "page", schema: Int32, desc: "The page number to return (starts from 1)"
    Koa.response 200, schema: Bytes, media_type: "image/*"
    Koa.response 500, "Page not found or not readable"
    Koa.response 304, "Page not modified (only available when `If-None-Match` is set)"
    Koa.tag "reader"
    get "/api/page/:tid/:eid/:page" do |env|
      begin
        tid = env.params.url["tid"]
        eid = env.params.url["eid"]
        page = env.params.url["page"].to_i
        prev_e_tag = env.request.headers["If-None-Match"]?

        title = Library.default.get_title tid
        raise "Title ID `#{tid}` not found" if title.nil?
        entry = title.get_entry eid
        raise "Entry ID `#{eid}` of `#{title.title}` not found" if entry.nil?
        img = entry.read_page page
        raise "Failed to load page #{page} of " \
              "`#{title.title}/#{entry.title}`" if img.nil?

        e_tag = Digest::SHA1.hexdigest img.data
        if prev_e_tag == e_tag
          env.response.status_code = 304
          ""
        else
          if entry.is_a? DirEntry
            cache_control = "no-cache, max-age=86400"
          else
            cache_control = "public, max-age=86400"
          end
          env.response.headers["ETag"] = e_tag
          env.response.headers["Cache-Control"] = cache_control
          send_img env, img
        end
      rescue e
        Logger.error e
        env.response.status_code = 500
        send_text env, e.message
      end
    end

    Koa.describe "Returns the cover image of a manga entry"
    Koa.path "tid", desc: "Title ID"
    Koa.path "eid", desc: "Entry ID"
    Koa.response 200, schema: Bytes, media_type: "image/*"
    Koa.response 304, "Page not modified (only available when `If-None-Match` is set)"
    Koa.response 500, "Page not found or not readable"
    Koa.tag "library"
    get "/api/cover/:tid/:eid" do |env|
      begin
        tid = env.params.url["tid"]
        eid = env.params.url["eid"]
        prev_e_tag = env.request.headers["If-None-Match"]?

        title = Library.default.get_title tid
        raise "Title ID `#{tid}` not found" if title.nil?
        entry = title.get_entry eid
        raise "Entry ID `#{eid}` of `#{title.title}` not found" if entry.nil?

        img = entry.get_thumbnail || entry.read_page 1
        raise "Failed to get cover of `#{title.title}/#{entry.title}`" \
           if img.nil?

        e_tag = Digest::SHA1.hexdigest img.data
        if prev_e_tag == e_tag
          env.response.status_code = 304
          ""
        else
          env.response.headers["ETag"] = e_tag
          send_img env, img
        end
      rescue e
        Logger.error e
        env.response.status_code = 500
        send_text env, e.message
      end
    end

    Koa.describe "Returns the book with title `tid`", <<-MD
    The entries and titles will be sorted by the default sorting method for the logged-in user.
    - Supply the `percentage` query parameter to include the reading progress
    - Supply the `slim` query parameter to strip away "display_name", "cover_url", and "mtime" from the returned object to speed up the loading time
    - Supply the `depth` query parameter to control the depth of nested titles to return.
      - When `depth` is 1, returns the top-level titles and sub-titles/entries one level in them
      - When `depth` is 0, returns the top-level titles without their sub-titles/entries
      - When `depth` is N, returns the top-level titles and sub-titles/entries N levels in them
      - When `depth` is negative, returns the entire library
    MD
    Koa.path "tid", desc: "Title ID"
    Koa.query "slim"
    Koa.query "depth"
    Koa.query "percentage"
    Koa.response 200, schema: "title"
    Koa.response 404, "Title not found"
    Koa.tag "library"
    get "/api/book/:tid" do |env|
      begin
        username = get_username env

        tid = env.params.url["tid"]
        title = Library.default.get_title tid
        raise "Title ID `#{tid}` not found" if title.nil?

        sort_opt = SortOptions.from_info_json title.dir, username

        slim = !env.params.query["slim"]?.nil?
        depth = env.params.query["depth"]?.try(&.to_i?) || -1
        percentage = !env.params.query["percentage"]?.nil?

        send_json env, title.build_json(slim: slim, depth: depth,
          sort_context: {username: username,
                         opt:      sort_opt}, percentage: percentage)
      rescue e
        Logger.error e
        env.response.status_code = 404
        send_text env, e.message
      end
    end

    Koa.describe "Returns the sorting option of a title or the library", <<-MD
    - If the query parameter `tid` is supplied, returns the sorting option of the title identified by the `tid`.
    - If the query parameter `tid` is missing, returns the sorting option of the library.
    MD
    Koa.query "tid"
    Koa.response 200, schema: {
      "method" => String?,
      "ascend" => Bool?,
      "error"  => String?,
    }
    Koa.tag "library"
    get "/api/sort_opt" do |env|
      username = get_username env

      tid = env.params.query["tid"]?
      dir = if tid
              (Library.default.get_title tid).not_nil!.dir
            else
              Library.default.dir
            end
      sort_opt = SortOptions.from_info_json dir, username
      send_json env, sort_opt.to_json
    rescue e
      Logger.error e
      send_json env, {
        "success" => false,
        "error"   => e.message,
      }.to_json
    end

    Koa.describe "Updates the sorting option of a title or the library", <<-MD
    - When the `tid` field is supplied in the body, updates the sorting option of the title identified by the `tid`.
    - When the `tid` field is missing in the body, updates the sorting option of the library.
    MD
    Koa.body schema: {
      "tid"    => String?,
      "method" => String,
      "ascend" => Bool,
    }
    Koa.response 200, schema: {
      "success" => Bool,
      "error"   => String?,
    }
    Koa.tag "library"
    put "/api/sort_opt" do |env|
      username = get_username env

      tid = env.params.json["tid"]?.try &.as String
      dir = if tid
              (Library.default.get_title tid).not_nil!.dir
            else
              Library.default.dir
            end

      method = env.params.json["sort"].as String
      ascend = env.params.json["ascend"].as Bool
      sort_opt = SortOptions.new method, ascend

      TitleInfo.new dir do |info|
        info.sort_by[username] = sort_opt.to_tuple
        info.save
      end
      send_json env, {
        "success" => true,
      }.to_json
    rescue e
      Logger.error e
      send_json env, {
        "success" => false,
        "error"   => e.message,
      }.to_json
    end

    Koa.describe "Returns the entire library with all titles and entries", <<-MD
    The titles will be sorted by the default sorting method for the logged-in user.
    - Supply the `slim` query parameter to strip away "display_name", "cover_url", and "mtime" from the returned object to speed up the loading time
    - Supply the `dpeth` query parameter to control the depth of nested titles to return.
    - Supply the `percentage` query parameter to include the reading progress
      - When `depth` is 1, returns the requested title and sub-titles/entries one level in it
      - When `depth` is 0, returns the requested title without its sub-titles/entries
      - When `depth` is N, returns the requested title and sub-titles/entries N levels in it
      - When `depth` is negative, returns the requested title and all sub-titles/entries in it
    MD
    Koa.query "slim"
    Koa.query "depth"
    Koa.query "percentage"
    Koa.response 200, schema: {
      "dir"              => String,
      "titles"           => ["title"],
      "title_percentage" => [Float64?],
    }
    Koa.tag "library"
    get "/api/library" do |env|
      username = get_username env

      sort_opt = SortOptions.from_info_json Library.default.dir, username

      slim = !env.params.query["slim"]?.nil?
      depth = env.params.query["depth"]?.try(&.to_i?) || -1
      percentage = !env.params.query["percentage"]?.nil?

      send_json env, Library.default.build_json(slim: slim, depth: depth,
        sort_context: {username: username,
                       opt:      sort_opt}, percentage: percentage)
    rescue e
      Logger.error e
      send_json env, {
        "success" => false,
        "error"   => e.message,
      }.to_json
    end

    Koa.describe "Returns the continue reading entries"
    Koa.response 200, schema: {
      "success"           => Bool,
      "error"             => String?,
      "entries"           => ["entry"],
      "entry_percentages" => [Float64],
    }
    Koa.tag "library"
    get "/api/library/continue_reading" do |env|
      username = get_username env
      cr_entries = Library.default.get_continue_reading_entries username

      json = JSON.build do |j|
        j.object do
          j.field "success" do
            j.bool true
          end
          j.field "entries" do
            j.array do
              cr_entries.each do |e|
                j.raw e[:entry].build_json
              end
            end
          end
          j.field "entry_percentages" do
            j.array do
              cr_entries.each do |e|
                j.number e[:percentage]
              end
            end
          end
        end
      end

      send_json env, json
    rescue e
      Logger.error e
      send_json env, {
        "success" => false,
        "error"   => e.message,
      }.to_json
    end

    Koa.describe "Returns the start reading titles"
    Koa.response 200, schema: {
      "success" => Bool,
      "error"   => String?,
      "titles"  => ["title"],
    }
    Koa.tag "library"
    get "/api/library/start_reading" do |env|
      username = get_username env
      titles = Library.default.get_start_reading_titles username

      json = JSON.build do |j|
        j.object do
          j.field "success" do
            j.bool true
          end
          j.field "titles" do
            j.array do
              titles.each do |t|
                j.raw t.build_json depth: 1
              end
            end
          end
        end
      end

      send_json env, json
    rescue e
      Logger.error e
      send_json env, {
        "success" => false,
        "error"   => e.message,
      }.to_json
    end

    Koa.describe "Returns the recently added items"
    Koa.response 200, schema: {
      "success" => Bool,
      "error"   => String?,
      "items"   => [{
        "item"       => "title | entry",
        "percentage" => Float64,
        "count"      => Int32,
      }],
    }
    Koa.tag "library"
    get "/api/library/recently_added" do |env|
      username = get_username env
      ra_entries = Library.default.get_recently_added_entries username

      json = JSON.build do |j|
        j.object do
          j.field "success" do
            j.bool true
          end
          j.field "items" do
            j.array do
              ra_entries.each do |e|
                j.object do
                  j.field "item" do
                    if e[:grouped_count] === 1
                      j.raw e[:entry].build_json
                    else
                      j.raw e[:entry].book.build_json depth: 0
                    end
                  end
                  j.field "percentage" do
                    j.number e[:percentage]
                  end
                  j.field "count" do
                    j.number e[:grouped_count]
                  end
                end
              end
            end
          end
        end
      end

      send_json env, json
    rescue e
      Logger.error e
      send_json env, {
        "success" => false,
        "error"   => e.message,
      }.to_json
    end

    Koa.describe "Triggers a library scan"
    Koa.tags ["admin", "library"]
    Koa.response 200, schema: {
      "milliseconds" => Float64,
      "titles"       => Int32,
    }
    post "/api/admin/scan" do |env|
      start = Time.utc
      Library.default.scan
      ms = (Time.utc - start).total_milliseconds
      send_json env, {
        "milliseconds" => ms,
        "titles"       => Library.default.titles.size,
      }.to_json
    end

    Koa.describe "Returns the thumbnail generation progress between 0 and 1"
    Koa.tags ["admin", "library"]
    Koa.response 200, schema: {
      "progress" => Float64,
    }
    get "/api/admin/thumbnail_progress" do |env|
      send_json env, {
        "progress" => Library.default.thumbnail_ctx.progress,
      }.to_json
    end

    Koa.describe "Triggers a thumbnail generation"
    Koa.tags ["admin", "library"]
    post "/api/admin/generate_thumbnails" do |env|
      spawn do
        Library.default.generate_thumbnails
      end
      send_text env, ""
    end

    Koa.describe "Deletes a user with `username`"
    Koa.tags ["admin", "users"]
    Koa.response 200, schema: "result"
    delete "/api/admin/user/delete/:username" do |env|
      begin
        username = env.params.url["username"]
        Storage.default.delete_user username
      rescue e
        Logger.error e
        send_json env, {
          "success" => false,
          "error"   => e.message,
        }.to_json
      else
        send_json env, {"success" => true}.to_json
      end
    end

    Koa.describe "Updates the reading progress of an entry or the whole title for the current user", <<-MD
      When `eid` is provided, sets the reading progress of the entry to `page`.

      When `eid` is omitted, updates the progress of the entire title. Specifically:

      - if `page` is 0, marks the entire title as unread
      - otherwise, marks the entire title as read
    MD
    Koa.path "tid", desc: "Title ID"
    Koa.query "eid", desc: "Entry ID", required: false
    Koa.path "page", desc: "The new page number indicating the progress"
    Koa.response 200, schema: "result"
    Koa.tag "progress"
    put "/api/progress/:tid/:page" do |env|
      begin
        username = get_username env
        title = (Library.default.get_title env.params.url["tid"]).not_nil!
        page = env.params.url["page"].to_i
        entry_id = env.params.query["eid"]?

        if !entry_id.nil?
          entry = title.get_entry(entry_id).not_nil!
          raise "incorrect page value" if page < 0 || page > entry.pages
          entry.save_progress username, page
        elsif page == 0
          title.unread_all username
        else
          title.read_all username
        end
      rescue e
        Logger.error e
        send_json env, {
          "success" => false,
          "error"   => e.message,
        }.to_json
      else
        send_json env, {"success" => true}.to_json
      end
    end

    Koa.describe "Updates the reading progress of multiple entries in a title"
    Koa.path "action", desc: "The action to perform. Can be either `read` or `unread`"
    Koa.path "tid", desc: "Title ID"
    Koa.body schema: {
      "ids" => [String],
    }, desc: "An array of entry IDs"
    Koa.response 200, schema: "result"
    Koa.tag "progress"
    put "/api/bulk_progress/:action/:tid" do |env|
      begin
        username = get_username env
        title = (Library.default.get_title env.params.url["tid"]).not_nil!
        action = env.params.url["action"]
        ids = env.params.json["ids"].as(Array).map &.as_s

        unless action.in? ["read", "unread"]
          raise "Unknow action #{action}"
        end
        title.bulk_progress action, ids, username
      rescue e
        Logger.error e
        send_json env, {
          "success" => false,
          "error"   => e.message,
        }.to_json
      else
        send_json env, {"success" => true}.to_json
      end
    end

    Koa.describe "Sets the display name of a title or an entry", <<-MD
      When `eid` is provided, apply the display name to the entry. Otherwise, apply the display name to the title identified by `tid`.
    MD
    Koa.tags ["admin", "library"]
    Koa.path "tid", desc: "Title ID"
    Koa.query "eid", desc: "Entry ID", required: false
    Koa.path "name", desc: "The new display name"
    Koa.response 200, schema: "result"
    put "/api/admin/display_name/:tid/:name" do |env|
      begin
        title = (Library.default.get_title env.params.url["tid"])
          .not_nil!
        name = env.params.url["name"]
        entry = env.params.query["eid"]?
        if entry.nil?
          title.set_display_name name
        else
          eobj = title.get_entry entry
          title.set_display_name eobj.not_nil!.title, name
        end
      rescue e
        Logger.error e
        send_json env, {
          "success" => false,
          "error"   => e.message,
        }.to_json
      else
        send_json env, {"success" => true}.to_json
      end
    end

    Koa.describe "Sets the sort title of a title or an entry", <<-MD
      When `eid` is provided, apply the sort title to the entry. Otherwise, apply the sort title to the title identified by `tid`.
    MD
    Koa.tags ["admin", "library"]
    Koa.path "tid", desc: "Title ID"
    Koa.query "eid", desc: "Entry ID", required: false
    Koa.query "name", desc: "The new sort title"
    Koa.response 200, schema: "result"
    put "/api/admin/sort_title/:tid" do |env|
      username = get_username env
      begin
        title = (Library.default.get_title env.params.url["tid"])
          .not_nil!
        name = env.params.query["name"]?
        entry = env.params.query["eid"]?
        if entry.nil?
          title.set_sort_title name, username
        else
          eobj = title.get_entry entry
          eobj.set_sort_title name, username unless eobj.nil?
        end
      rescue e
        Logger.error e
        send_json env, {
          "success" => false,
          "error"   => e.message,
        }.to_json
      else
        send_json env, {"success" => true}.to_json
      end
    end

    ws "/api/admin/mangadex/queue" do |socket, env|
      interval_raw = env.params.query["interval"]?
      interval = (interval_raw.to_i? if interval_raw) || 5
      loop do
        socket.send({
          "jobs"   => Queue.default.get_all.reverse,
          "paused" => Queue.default.paused?,
        }.to_json)
        sleep interval.seconds
      end
    end

    Koa.describe "Returns the current download queue", <<-MD
      On error, returns a JSON that contains the error message in the `error` field.
    MD
    Koa.tags ["admin", "downloader"]
    Koa.response 200, schema: {
      "success" => Bool,
      "error"   => String?,
      "paused"  => Bool?,
      "jobs?"   => [{
        "pages"         => Int32,
        "success_count" => Int32,
        "fail_count"    => Int32,
        "time"          => Int64,
      }.merge(s %w(id manga_id title manga_title status_message status))],
    }
    get "/api/admin/mangadex/queue" do |env|
      begin
        send_json env, {
          "jobs"    => Queue.default.get_all.reverse,
          "paused"  => Queue.default.paused?,
          "success" => true,
        }.to_json
      rescue e
        Logger.error e
        send_json env, {
          "success" => false,
          "error"   => e.message,
        }.to_json
      end
    end

    Koa.describe "Perform an action on a download job or all jobs in the queue", <<-MD
      The `action` parameter can be `delete`, `retry`, `pause` or `resume`.

      When `action` is `pause` or `resume`, pauses or resumes the download queue, respectively.

      When `action` is set to `delete`, the behavior depends on `id`. If `id` is provided, deletes the specific job identified by the ID. Otherwise, deletes all **completed** jobs in the queue.

      When `action` is set to `retry`, the behavior depends on `id`. If `id` is provided, restarts the job identified by the ID. Otherwise, retries all jobs in the `Error` or `MissingPages` status in the queue.
    MD
    Koa.tags ["admin", "downloader"]
    Koa.path "action", desc: "The action to perform. It should be one of the followins: `delete`, `retry`, `pause` and `resume`."
    Koa.query "id", required: false, desc: "A job ID"
    Koa.response 200, schema: "result"
    post "/api/admin/mangadex/queue/:action" do |env|
      begin
        action = env.params.url["action"]
        id = env.params.query["id"]?
        case action
        when "delete"
          if id.nil?
            Queue.default.delete_status Queue::JobStatus::Completed
          else
            Queue.default.delete id
          end
        when "retry"
          if id.nil?
            Queue.default.reset
          else
            Queue.default.reset id
          end
        when "pause"
          Queue.default.pause
        when "resume"
          Queue.default.resume
        else
          raise "Unknown queue action #{action}"
        end

        send_json env, {"success" => true}.to_json
      rescue e
        Logger.error e
        send_json env, {
          "success" => false,
          "error"   => e.message,
        }.to_json
      end
    end

    Koa.describe "Uploads a file to the server", <<-MD
      Currently the only supported value for the `target` parameter is `cover`.

      ### Cover

      Uploads a cover image for a title or an entry.

      Query parameters:
      - `tid`: A title ID
      - `eid`: (Optional) An entry ID

      When `eid` is omitted, the new cover image will be applied to the title. Otherwise, applies the image to the specified entry.
    MD
    Koa.tag "admin"
    Koa.body media_type: "multipart/form-data", schema: {
      "file" => Bytes,
    }
    Koa.response 200, schema: "result"
    post "/api/admin/upload/:target" do |env|
      begin
        target = env.params.url["target"]

        HTTP::FormData.parse env.request do |part|
          next if part.name != "file"

          filename = part.filename
          if filename.nil?
            raise "No file uploaded"
          end

          case target
          when "cover"
            title_id = env.params.query["tid"]
            entry_id = env.params.query["eid"]?
            title = Library.default.get_title(title_id).not_nil!

            unless SUPPORTED_IMG_TYPES.includes? \
                     MIME.from_filename? filename
              raise "The uploaded image must be either JPEG or PNG"
            end

            ext = File.extname filename
            upload = Upload.new Config.current.upload_path
            url = upload.path_to_url upload.save "img", ext, part.body

            if url.nil?
              raise "Failed to generate a public URL for the uploaded file"
            end

            if entry_id.nil?
              title.set_cover_url url
            else
              entry_name = title.get_entry(entry_id).not_nil!.title
              title.set_cover_url entry_name, url
            end
          else
            raise "Unkown upload target #{target}"
          end

          send_json env, {"success" => true}.to_json
          env.response.close
        end

        raise "No part with name `file` found"
      rescue e
        Logger.error e
        send_json env, {
          "success" => false,
          "error"   => e.message,
        }.to_json
      end
    end

    Koa.describe "Returns a list of available plugins"
    Koa.tags ["admin", "downloader"]
    Koa.query "plugin", schema: String
    Koa.response 200, schema: {
      "success" => Bool,
      "error"   => String?,
      "plugins" => [{
        "id"    => String,
        "title" => String,
      }],
    }
    get "/api/admin/plugin" do |env|
      begin
        send_json env, {
          "success" => true,
          "plugins" => Plugin.list,
        }.to_json
      rescue e
        Logger.error e
        send_json env, {
          "success" => false,
          "error"   => e.message,
        }.to_json
      end
    end

    Koa.describe "Returns the metadata of a plugin"
    Koa.tags ["admin", "downloader"]
    Koa.query "plugin", schema: String
    Koa.response 200, schema: {
      "success" => Bool,
      "error"   => String?,
      "info"    => {
        "dir"          => String,
        "id"           => String,
        "title"        => String,
        "placeholder"  => String,
        "wait_seconds" => Int32,
        "version"      => Int32,
        "settings"     => {} of String => String,
      },
      "subscribable" => Bool,
    }
    get "/api/admin/plugin/info" do |env|
      begin
        plugin = Plugin.new env.params.query["plugin"].as String
        send_json env, {
          "success"      => true,
          "info"         => plugin.info,
          "subscribable" => plugin.can_subscribe?,
        }.to_json
      rescue e
        Logger.error e
        send_json env, {
          "success" => false,
          "error"   => e.message,
        }.to_json
      end
    end

    Koa.describe "Searches for manga matching the given query from a plugin", <<-MD
    Only available for plugins targeting API v2 or above.
    MD
    Koa.tags ["admin", "downloader"]
    Koa.query "plugin", schema: String
    Koa.query "query", schema: String
    Koa.response 200, schema: {
      "success" => Bool,
      "error"   => String?,
      "manga"   => [{
        "id"    => String,
        "title" => String,
      }],
    }
    get "/api/admin/plugin/search" do |env|
      begin
        query = env.params.query["query"].as String
        plugin = Plugin.new env.params.query["plugin"].as String

        manga_ary = plugin.search_manga(query).as_a
        send_json env, {
          "success" => true,
          "manga"   => manga_ary,
        }.to_json
      rescue e
        Logger.error e
        send_json env, {
          "success" => false,
          "error"   => e.message,
        }.to_json
      end
    end

    Koa.describe "Creates a new subscription"
    Koa.tags ["admin", "downloader", "subscription"]
    Koa.body schema: {
      "plugin"   => String,
      "manga"    => String,
      "manga_id" => String,
      "name"     => String,
      "filters"  => ["filter"],
    }
    Koa.response 200, schema: "result"
    post "/api/admin/plugin/subscriptions" do |env|
      begin
        plugin_id = env.params.json["plugin"].as String
        manga_title = env.params.json["manga"].as String
        manga_id = env.params.json["manga_id"].as String
        filters = env.params.json["filters"].as(Array(JSON::Any)).map do |f|
          Filter.from_json f.to_json
        end
        name = env.params.json["name"].as String

        sub = Subscription.new plugin_id, manga_id, manga_title, name
        sub.filters = filters

        plugin = Plugin.new plugin_id
        plugin.subscribe sub

        send_json env, {
          "success" => true,
        }.to_json
      rescue e
        Logger.error e
        send_json env, {
          "success" => false,
          "error"   => e.message,
        }.to_json
      end
    end

    Koa.describe "Returns the list of subscriptions for a plugin"
    Koa.tags ["admin", "downloader", "subscription"]
    Koa.query "plugin", desc: "The ID of the plugin"
    Koa.response 200, schema: {
      "success"       => Bool,
      "error"         => String?,
      "subscriptions" => ["subscription"],
    }
    get "/api/admin/plugin/subscriptions" do |env|
      begin
        pid = env.params.query["plugin"].as String
        send_json env, {
          "success"       => true,
          "subscriptions" => Plugin.new(pid).list_subscriptions,
        }.to_json
      rescue e
        Logger.error e
        send_json env, {
          "success" => false,
          "error"   => e.message,
        }.to_json
      end
    end

    Koa.describe "Deletes a subscription"
    Koa.tags ["admin", "downloader", "subscription"]
    Koa.body schema: {
      "plugin"       => String,
      "subscription" => String,
    }
    Koa.response 200, schema: "result"
    delete "/api/admin/plugin/subscriptions" do |env|
      begin
        pid = env.params.query["plugin"].as String
        sid = env.params.query["subscription"].as String

        Plugin.new(pid).unsubscribe sid

        send_json env, {
          "success" => true,
        }.to_json
      rescue e
        Logger.error e
        send_json env, {
          "success" => false,
          "error"   => e.message,
        }.to_json
      end
    end

    Koa.describe "Checks for updates for a subscription"
    Koa.tags ["admin", "downloader", "subscription"]
    Koa.body schema: {
      "plugin"       => String,
      "subscription" => String,
    }
    Koa.response 200, schema: "result"
    post "/api/admin/plugin/subscriptions/update" do |env|
      pid = env.params.query["plugin"].as String
      sid = env.params.query["subscription"].as String

      Plugin.new(pid).check_subscription sid

      send_json env, {
        "success" => true,
      }.to_json
    rescue e
      Logger.error e
      send_json env, {
        "success" => false,
        "error"   => e.message,
      }.to_json
    end

    Koa.describe "Lists the chapters in a title from a plugin"
    Koa.tags ["admin", "downloader"]
    Koa.query "plugin", schema: String
    Koa.query "query", schema: String
    Koa.response 200, schema: {
      "success"   => Bool,
      "error"     => String?,
      "chapters?" => [{
        "id"     => String,
        "title?" => String,
      }],
      "title" => String?,
    }
    get "/api/admin/plugin/list" do |env|
      begin
        query = env.params.query["query"].as String
        plugin = Plugin.new env.params.query["plugin"].as String

        json = plugin.list_chapters query

        if plugin.info.version == 1
          chapters = json["chapters"]
          title = json["title"]
        else
          chapters = json
          title = nil
        end

        send_json env, {
          "success"  => true,
          "chapters" => chapters,
          "title"    => title,
        }.to_json
      rescue e
        Logger.error e
        send_json env, {
          "success" => false,
          "error"   => e.message,
        }.to_json
      end
    end

    Koa.describe "Adds a list of chapters from a plugin to the download queue"
    Koa.tags ["admin", "downloader"]
    Koa.body schema: {
      "plugin"   => String,
      "title"    => String,
      "chapters" => [{
        "id"    => String,
        "title" => String,
      }],
    }
    Koa.response 200, schema: {
      "success" => Int32,
      "fail"    => Int32,
    }
    post "/api/admin/plugin/download" do |env|
      begin
        plugin = Plugin.new env.params.json["plugin"].as String
        chapters = env.params.json["chapters"].as Array(JSON::Any)
        manga_title = env.params.json["title"].as String

        jobs = chapters.map { |ch|
          Queue::Job.new(
            "#{plugin.info.id}-#{Base64.encode ch["id"].as_s}",
            "", # manga_id
            ch["title"].as_s,
            manga_title,
            Queue::JobStatus::Pending,
            Time.utc
          )
        }
        inserted_count = Queue.default.push jobs
        send_json env, {
          "success": inserted_count,
          "fail":    jobs.size - inserted_count,
        }.to_json
      rescue e
        Logger.error e
        send_json env, {
          "success" => false,
          "error"   => e.message,
        }.to_json
      end
    end

    Koa.describe "Returns the image dimensions of all pages in an entry"
    Koa.path "tid", desc: "A title ID"
    Koa.path "eid", desc: "An entry ID"
    Koa.tag "reader"
    Koa.response 200, schema: {
      "success"     => Bool,
      "error"       => String?,
      "dimensions?" => [{
        "width"  => Int32,
        "height" => Int32,
      }],
    }
    Koa.response 304, "Not modified (only available when `If-None-Match` is set)"
    get "/api/dimensions/:tid/:eid" do |env|
      begin
        tid = env.params.url["tid"]
        eid = env.params.url["eid"]
        prev_e_tag = env.request.headers["If-None-Match"]?

        title = Library.default.get_title tid
        raise "Title ID `#{tid}` not found" if title.nil?
        entry = title.get_entry eid
        raise "Entry ID `#{eid}` of `#{title.title}` not found" if entry.nil?

        if entry.is_a? DirEntry
          file_hash = Digest::SHA1.hexdigest(entry.path + entry.mtime.to_s + entry.size)
        else
          file_hash = Digest::SHA1.hexdigest(entry.path + entry.mtime.to_s)
        end
        e_tag = "W/#{file_hash}"
        if e_tag == prev_e_tag
          env.response.status_code = 304
          send_text env, ""
        else
          sizes = entry.page_dimensions
          if entry.is_a? DirEntry
            cache_control = "no-cache, max-age=86400"
          else
            cache_control = "public, max-age=86400"
          end
          env.response.headers["ETag"] = e_tag
          env.response.headers["Cache-Control"] = cache_control
          send_json env, {
            "success"    => true,
            "dimensions" => sizes,
          }.to_json
        end
      rescue e
        Logger.error e
        send_json env, {
          "success" => false,
          "error"   => e.message,
        }.to_json
      end
    end

    Koa.describe "Downloads an entry"
    Koa.path "tid", desc: "A title ID"
    Koa.path "eid", desc: "An entry ID"
    Koa.response 200, schema: Bytes
    Koa.response 404, "Entry not found"
    Koa.tags ["library", "reader"]
    get "/api/download/:tid/:eid" do |env|
      begin
        title = (Library.default.get_title env.params.url["tid"]).not_nil!
        entry = (title.get_entry env.params.url["eid"]).not_nil!

        send_attachment env, entry.path
      rescue e
        Logger.error e
        env.response.status_code = 404
        send_text env, e.message
      end
    end

    Koa.describe "Gets the tags of a title"
    Koa.path "tid", desc: "A title ID"
    Koa.response 200, schema: {
      "success" => Bool,
      "error"   => String?,
      "tags"    => [String?],
    }
    Koa.tags ["library", "tags"]
    get "/api/tags/:tid" do |env|
      begin
        title = (Library.default.get_title env.params.url["tid"]).not_nil!
        tags = title.tags

        send_json env, {
          "success" => true,
          "tags"    => tags,
        }.to_json
      rescue e
        Logger.error e
        send_json env, {
          "success" => false,
          "error"   => e.message,
        }.to_json
      end
    end

    Koa.describe "Returns all tags"
    Koa.response 200, schema: {
      "success" => Bool,
      "error"   => String?,
      "tags"    => [String?],
    }
    Koa.tags ["library", "tags"]
    get "/api/tags" do |env|
      begin
        tags = Storage.default.list_tags
        send_json env, {
          "success" => true,
          "tags"    => tags,
        }.to_json
      rescue e
        Logger.error e
        send_json env, {
          "success" => false,
          "error"   => e.message,
        }.to_json
      end
    end

    Koa.describe "Adds a new tag to a title"
    Koa.path "tid", desc: "A title ID"
    Koa.response 200, schema: "result"
    Koa.tags ["admin", "library", "tags"]
    put "/api/admin/tags/:tid/:tag" do |env|
      begin
        title = (Library.default.get_title env.params.url["tid"]).not_nil!
        tag = env.params.url["tag"]

        title.add_tag tag
        send_json env, {
          "success" => true,
          "error"   => nil,
        }.to_json
      rescue e
        Logger.error e
        send_json env, {
          "success" => false,
          "error"   => e.message,
        }.to_json
      end
    end

    Koa.describe "Deletes a tag from a title"
    Koa.path "tid", desc: "A title ID"
    Koa.response 200, schema: "result"
    Koa.tags ["admin", "library", "tags"]
    delete "/api/admin/tags/:tid/:tag" do |env|
      begin
        title = (Library.default.get_title env.params.url["tid"]).not_nil!
        tag = env.params.url["tag"]

        title.delete_tag tag
        send_json env, {
          "success" => true,
          "error"   => nil,
        }.to_json
      rescue e
        Logger.error e
        send_json env, {
          "success" => false,
          "error"   => e.message,
        }.to_json
      end
    end

    Koa.describe "Lists all missing titles"
    Koa.response 200, schema: {
      "success" => Bool,
      "error"   => String?,
      "titles?" => [{
        "path"      => String,
        "id"        => String,
        "signature" => String,
      }],
    }
    Koa.tags ["admin", "library"]
    get "/api/admin/titles/missing" do |env|
      begin
        send_json env, {
          "success" => true,
          "error"   => nil,
          "titles"  => Storage.default.missing_titles,
        }.to_json
      rescue e
        Logger.error e
        send_json env, {
          "success" => false,
          "error"   => e.message,
        }.to_json
      end
    end

    Koa.describe "Lists all missing entries"
    Koa.response 200, schema: {
      "success"  => Bool,
      "error"    => String?,
      "entries?" => [{
        "path"      => String,
        "id"        => String,
        "signature" => String,
      }],
    }
    Koa.tags ["admin", "library"]
    get "/api/admin/entries/missing" do |env|
      begin
        send_json env, {
          "success" => true,
          "error"   => nil,
          "entries" => Storage.default.missing_entries,
        }.to_json
      rescue e
        Logger.error e
        send_json env, {
          "success" => false,
          "error"   => e.message,
        }.to_json
      end
    end

    Koa.describe "Deletes all missing titles"
    Koa.response 200, schema: "result"
    Koa.tags ["admin", "library"]
    delete "/api/admin/titles/missing" do |env|
      begin
        Storage.default.delete_missing_title
        send_json env, {
          "success" => true,
          "error"   => nil,
        }.to_json
      rescue e
        Logger.error e
        send_json env, {
          "success" => false,
          "error"   => e.message,
        }.to_json
      end
    end

    Koa.describe "Deletes all missing entries"
    Koa.response 200, schema: "result"
    Koa.tags ["admin", "library"]
    delete "/api/admin/entries/missing" do |env|
      begin
        Storage.default.delete_missing_entry
        send_json env, {
          "success" => true,
          "error"   => nil,
        }.to_json
      rescue e
        Logger.error e
        send_json env, {
          "success" => false,
          "error"   => e.message,
        }.to_json
      end
    end

    Koa.describe "Deletes a missing title identified by `tid`", <<-MD
    Does nothing if the given `tid` is not found or if the title is not missing.
    MD
    Koa.response 200, schema: "result"
    Koa.tags ["admin", "library"]
    delete "/api/admin/titles/missing/:tid" do |env|
      begin
        tid = env.params.url["tid"]
        Storage.default.delete_missing_title tid
        send_json env, {
          "success" => true,
          "error"   => nil,
        }.to_json
      rescue e
        Logger.error e
        send_json env, {
          "success" => false,
          "error"   => e.message,
        }.to_json
      end
    end

    Koa.describe "Deletes a missing entry identified by `eid`", <<-MD
    Does nothing if the given `eid` is not found or if the entry is not missing.
    MD
    Koa.response 200, schema: "result"
    Koa.tags ["admin", "library"]
    delete "/api/admin/entries/missing/:eid" do |env|
      begin
        eid = env.params.url["eid"]
        Storage.default.delete_missing_entry eid
        send_json env, {
          "success" => true,
          "error"   => nil,
        }.to_json
      rescue e
        Logger.error e
        send_json env, {
          "success" => false,
          "error"   => e.message,
        }.to_json
      end
    end

    doc = Koa.generate
    @@api_json = doc.to_json if doc

    get "/openapi.json" do |env|
      if @@api_json
        send_json env, @@api_json
      else
        env.response.status_code = 404
      end
    end
  end
end
