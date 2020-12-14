require "./router"
require "../mangadex/*"
require "../upload"
require "koa"

class APIRouter < Router
  @@api_json : String?

  macro s(fields)
    {
      {% for field in fields %}
        {{field}} => "string",
      {% end %}
    }
  end

  def initialize
    Koa.init "Mango API", version: MANGO_VERSION, desc: <<-MD
      ## Terminalogies

      - Entry: An entry is a `cbz`/`cbr` file in your library. Depending on how you organize your manga collection, an entry can contain a chapter, a volume or even an entire manga.
      - Title: A title contains a list of entries and optionally some sub-titles. For example, your can have a title to store a manga, and  it contains a list of sub-titles representing the volumes in the manga. Each sub-title would then contain a list of entries representing the chapters in the volume.
      - Library: The library is a collection of the top-level titles, and it does not contain entries (though the titles do). A Mango instance can only have one library.

      ## Authentication

      All endpoints require authentication. After logging in, your session ID would be stored as a cookie named `mango-sessid-#{Config.current.port}`, which can be used to authenticate the API access. Note that all admin API enpoints (`/api/admin/...`) require the logged in user to have admin access.
    MD

    Koa.cookie_auth "cookie", "mango-sessid-#{Config.current.port}"
    Koa.global_tag "admin", desc: <<-MD
      These are the admin endpoints only accessible for users with admin access. A non-admin user will get HTTP 403 when calling the endpoints.
    MD

    Koa.binary "binary", desc: "A binary file"
    Koa.array "entryAry", "$entry", desc: "An array of entries"
    Koa.array "titleAry", "$title", desc: "An array of titles"
    Koa.array "strAry", "string", desc: "An array of strings"

    entry_schema = {
      "pages" => "integer",
      "mtime" => "integer",
    }.merge s %w(zip_path title size id title_id display_name cover_url)
    Koa.object "entry", entry_schema, desc: "An entry in a book"

    title_schema = {
      "mtime"   => "integer",
      "entries" => "$entryAry",
      "titles"  => "$titleAry",
      "parents" => "$strAry",
    }.merge s %w(dir title id display_name cover_url)
    Koa.object "title", title_schema,
      desc: "A manga title (a collection of entries and sub-titles)"

    Koa.object "library", {
      "dir"    => "string",
      "titles" => "$titleAry",
    }, desc: "A library containing a list of top-level titles"

    Koa.object "scanResult", {
      "milliseconds" => "integer",
      "titles"       => "integer",
    }

    Koa.object "progressResult", {
      "progress" => "number",
    }

    Koa.object "result", {
      "success" => "boolean",
      "error"   => "string?",
    }

    mc_schema = {
      "groups" => "object",
    }.merge s %w(id title volume chapter language full_title time manga_title manga_id)
    Koa.object "mangadexChapter", mc_schema, desc: "A MangaDex chapter"

    Koa.array "chapterAry", "$mangadexChapter"

    mm_schema = {
      "chapers" => "$chapterAry",
    }.merge s %w(id title description author artist cover_url)
    Koa.object "mangadexManga", mm_schema, desc: "A MangaDex manga"

    Koa.object "chaptersObj", {
      "chapters" => "$chapterAry",
    }

    Koa.object "successFailCount", {
      "success" => "integer",
      "fail"    => "integer",
    }

    job_schema = {
      "pages"         => "integer",
      "success_count" => "integer",
      "fail_count"    => "integer",
      "time"          => "integer",
    }.merge s %w(id manga_id title manga_title status_message status)
    Koa.object "job", job_schema, desc: "A download job in the queue"

    Koa.array "jobAry", "$job"

    Koa.object "jobs", {
      "success" => "boolean",
      "paused"  => "boolean",
      "jobs"    => "$jobAry",
    }

    Koa.object "binaryUpload", {
      "file" => "$binary",
    }

    Koa.object "pluginListBody", {
      "plugin" => "string",
      "query"  => "string",
    }

    Koa.object "pluginChapter", {
      "id"    => "string",
      "title" => "string",
    }

    Koa.array "pluginChapterAry", "$pluginChapter"

    Koa.object "pluginList", {
      "success"  => "boolean",
      "chapters" => "$pluginChapterAry?",
      "title"    => "string?",
      "error"    => "string?",
    }

    Koa.object "pluginDownload", {
      "plugin"   => "string",
      "title"    => "string",
      "chapters" => "$pluginChapterAry",
    }

    Koa.object "dimension", {
      "width"  => "integer",
      "height" => "integer",
    }

    Koa.array "dimensionAry", "$dimension"

    Koa.object "dimensionResult", {
      "success"    => "boolean",
      "dimensions" => "$dimensionAry?",
      "error"      => "string?",
    }

    Koa.object "ids", {
      "ids" => "$strAry",
    }

    Koa.describe "Returns a page in a manga entry"
    Koa.path "tid", desc: "Title ID"
    Koa.path "eid", desc: "Entry ID"
    Koa.path "page", type: "integer", desc: "The page number to return (starts from 1)"
    Koa.response 200, ref: "$binary", media_type: "image/*"
    Koa.response 500, "Page not found or not readable"
    get "/api/page/:tid/:eid/:page" do |env|
      begin
        tid = env.params.url["tid"]
        eid = env.params.url["eid"]
        page = env.params.url["page"].to_i

        title = @context.library.get_title tid
        raise "Title ID `#{tid}` not found" if title.nil?
        entry = title.get_entry eid
        raise "Entry ID `#{eid}` of `#{title.title}` not found" if entry.nil?
        img = entry.read_page page
        raise "Failed to load page #{page} of " \
              "`#{title.title}/#{entry.title}`" if img.nil?

        send_img env, img
      rescue e
        @context.error e
        env.response.status_code = 500
        e.message
      end
    end

    Koa.describe "Returns the cover image of a manga entry"
    Koa.path "tid", desc: "Title ID"
    Koa.path "eid", desc: "Entry ID"
    Koa.response 200, ref: "$binary", media_type: "image/*"
    Koa.response 500, "Page not found or not readable"
    get "/api/cover/:tid/:eid" do |env|
      begin
        tid = env.params.url["tid"]
        eid = env.params.url["eid"]

        title = @context.library.get_title tid
        raise "Title ID `#{tid}` not found" if title.nil?
        entry = title.get_entry eid
        raise "Entry ID `#{eid}` of `#{title.title}` not found" if entry.nil?

        img = entry.get_thumbnail || entry.read_page 1
        raise "Failed to get cover of `#{title.title}/#{entry.title}`" \
           if img.nil?

        send_img env, img
      rescue e
        @context.error e
        env.response.status_code = 500
        e.message
      end
    end

    Koa.describe "Returns the book with title `tid`"
    Koa.path "tid", desc: "Title ID"
    Koa.response 200, ref: "$title"
    Koa.response 404, "Title not found"
    get "/api/book/:tid" do |env|
      begin
        tid = env.params.url["tid"]
        title = @context.library.get_title tid
        raise "Title ID `#{tid}` not found" if title.nil?

        send_json env, title.to_json
      rescue e
        @context.error e
        env.response.status_code = 404
        e.message
      end
    end

    Koa.describe "Returns the entire library with all titles and entries"
    Koa.response 200, ref: "$library"
    get "/api/library" do |env|
      send_json env, @context.library.to_json
    end

    Koa.describe "Triggers a library scan"
    Koa.tag "admin"
    Koa.response 200, ref: "$scanResult"
    post "/api/admin/scan" do |env|
      start = Time.utc
      @context.library.scan
      ms = (Time.utc - start).total_milliseconds
      send_json env, {
        "milliseconds" => ms,
        "titles"       => @context.library.titles.size,
      }.to_json
    end

    Koa.describe "Returns the thumbanil generation progress between 0 and 1"
    Koa.tag "admin"
    Koa.response 200, ref: "$progressResult"
    get "/api/admin/thumbnail_progress" do |env|
      send_json env, {
        "progress" => Library.default.thumbnail_generation_progress,
      }.to_json
    end

    Koa.describe "Triggers a thumbanil generation"
    Koa.tag "admin"
    post "/api/admin/generate_thumbnails" do |env|
      spawn do
        Library.default.generate_thumbnails
      end
    end

    Koa.describe "Deletes a user with `username`"
    Koa.tag "admin"
    Koa.response 200, ref: "$result"
    delete "/api/admin/user/delete/:username" do |env|
      begin
        username = env.params.url["username"]
        @context.storage.delete_user username
      rescue e
        @context.error e
        send_json env, {
          "success" => false,
          "error"   => e.message,
        }.to_json
      else
        send_json env, {"success" => true}.to_json
      end
    end

    Koa.describe "Updates the reading progress of an entry or the whole title for the current user", <<-MD
      When `eid` is provided, sets the reading progress the the entry to `page`.

      When `eid` is omitted, updates the progress of the entire title. Specifically:

      - if `page` is 0, marks the entire title as unread
      - otherwise, marks the entire title as read
    MD
    Koa.path "tid", desc: "Title ID"
    Koa.query "eid", desc: "Entry ID", required: false
    Koa.path "page", desc: "The new page number indicating the progress"
    Koa.response 200, ref: "$result"
    put "/api/progress/:tid/:page" do |env|
      begin
        username = get_username env
        title = (@context.library.get_title env.params.url["tid"]).not_nil!
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
        @context.error e
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
    Koa.body ref: "$ids", desc: "An array of entry IDs"
    Koa.response 200, ref: "$result"
    put "/api/bulk_progress/:action/:tid" do |env|
      begin
        username = get_username env
        title = (@context.library.get_title env.params.url["tid"]).not_nil!
        action = env.params.url["action"]
        ids = env.params.json["ids"].as(Array).map &.as_s

        unless action.in? ["read", "unread"]
          raise "Unknow action #{action}"
        end
        title.bulk_progress action, ids, username
      rescue e
        @context.error e
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
    Koa.tag "admin"
    Koa.path "tid", desc: "Title ID"
    Koa.query "eid", desc: "Entry ID", required: false
    Koa.path "name", desc: "The new display name"
    Koa.response 200, ref: "$result"
    put "/api/admin/display_name/:tid/:name" do |env|
      begin
        title = (@context.library.get_title env.params.url["tid"])
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
        @context.error e
        send_json env, {
          "success" => false,
          "error"   => e.message,
        }.to_json
      else
        send_json env, {"success" => true}.to_json
      end
    end

    Koa.describe "Returns a MangaDex manga identified by `id`", <<-MD
      On error, returns a JSON that contains the error message in the `error` field.
    MD
    Koa.tag "admin"
    Koa.path "id", desc: "A MangaDex manga ID"
    Koa.response 200, ref: "$mangadexManga"
    get "/api/admin/mangadex/manga/:id" do |env|
      begin
        id = env.params.url["id"]
        api = MangaDex::API.default
        manga = api.get_manga id
        send_json env, manga.to_info_json
      rescue e
        @context.error e
        send_json env, {"error" => e.message}.to_json
      end
    end

    Koa.describe "Adds a list of MangaDex chapters to the download queue", <<-MD
      On error, returns a JSON that contains the error message in the `error` field.
    MD
    Koa.tag "admin"
    Koa.body ref: "$chaptersObj"
    Koa.response 200, ref: "$successFailCount"
    post "/api/admin/mangadex/download" do |env|
      begin
        chapters = env.params.json["chapters"].as(Array).map { |c| c.as_h }
        jobs = chapters.map { |chapter|
          Queue::Job.new(
            chapter["id"].as_s,
            chapter["manga_id"].as_s,
            chapter["full_title"].as_s,
            chapter["manga_title"].as_s,
            Queue::JobStatus::Pending,
            Time.unix chapter["time"].as_s.to_i
          )
        }
        inserted_count = @context.queue.push jobs
        send_json env, {
          "success": inserted_count,
          "fail":    jobs.size - inserted_count,
        }.to_json
      rescue e
        @context.error e
        send_json env, {"error" => e.message}.to_json
      end
    end

    ws "/api/admin/mangadex/queue" do |socket, env|
      interval_raw = env.params.query["interval"]?
      interval = (interval_raw.to_i? if interval_raw) || 5
      loop do
        socket.send({
          "jobs"   => @context.queue.get_all,
          "paused" => @context.queue.paused?,
        }.to_json)
        sleep interval.seconds
      end
    end

    Koa.describe "Returns the current download queue", <<-MD
      On error, returns a JSON that contains the error message in the `error` field.
    MD
    Koa.tag "admin"
    Koa.response 200, ref: "$jobs"
    get "/api/admin/mangadex/queue" do |env|
      begin
        jobs = @context.queue.get_all
        send_json env, {
          "jobs"    => jobs,
          "paused"  => @context.queue.paused?,
          "success" => true,
        }.to_json
      rescue e
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

      When `action` is set to `retry`, the behaviro depends on `id`. If `id` is provided, restarts the job identified by the ID. Otherwise, retries all jobs in the `Error` or `MissingPages` status in the queue.
    MD
    Koa.tag "admin"
    Koa.path "action", desc: "The action to perform. It should be one of the followins: `delete`, `retry`, `pause` and `resume`."
    Koa.query "id", required: false, desc: "A job ID"
    Koa.response 200, ref: "$result"
    post "/api/admin/mangadex/queue/:action" do |env|
      begin
        action = env.params.url["action"]
        id = env.params.query["id"]?
        case action
        when "delete"
          if id.nil?
            @context.queue.delete_status Queue::JobStatus::Completed
          else
            @context.queue.delete id
          end
        when "retry"
          if id.nil?
            @context.queue.reset
          else
            @context.queue.reset id
          end
        when "pause"
          @context.queue.pause
        when "resume"
          @context.queue.resume
        else
          raise "Unknown queue action #{action}"
        end

        send_json env, {"success" => true}.to_json
      rescue e
        send_json env, {
          "success" => false,
          "error"   => e.message,
        }.to_json
      end
    end

    Koa.describe "Uploads a file to the server", <<-MD
      Currently the only supported value for the `targe` parameter is `cover`.

      ### Cover

      Uploads a cover image for a title or an entry.

      Query parameters:
      - `tid`: A title ID
      - `eid`: (Optional) An entry ID

      When `eid` is omitted, the new cover image will be applied to the title. Otherwise, applies the image to the specified entry.
    MD
    Koa.tag "admin"
    Koa.body type: "multipart/form-data", ref: "$binaryUpload"
    Koa.response 200, ref: "$result"
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
            title = @context.library.get_title(title_id).not_nil!

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
        send_json env, {
          "success" => false,
          "error"   => e.message,
        }.to_json
      end
    end

    Koa.describe "Lists the chapters in a title from a plugin"
    Koa.tag "admin"
    Koa.body ref: "$pluginListBody"
    Koa.response 200, ref: "$pluginList"
    get "/api/admin/plugin/list" do |env|
      begin
        query = env.params.query["query"].as String
        plugin = Plugin.new env.params.query["plugin"].as String

        json = plugin.list_chapters query
        chapters = json["chapters"]
        title = json["title"]

        send_json env, {
          "success"  => true,
          "chapters" => chapters,
          "title"    => title,
        }.to_json
      rescue e
        send_json env, {
          "success" => false,
          "error"   => e.message,
        }.to_json
      end
    end

    Koa.describe "Adds a list of chapters from a plugin to the download queue"
    Koa.tag "admin"
    Koa.body ref: "$pluginDownload"
    Koa.response 200, ref: "$successFailCount"
    post "/api/admin/plugin/download" do |env|
      begin
        plugin = Plugin.new env.params.json["plugin"].as String
        chapters = env.params.json["chapters"].as Array(JSON::Any)
        manga_title = env.params.json["title"].as String

        jobs = chapters.map { |ch|
          Queue::Job.new(
            "#{plugin.info.id}-#{ch["id"]}",
            "", # manga_id
            ch["title"].as_s,
            manga_title,
            Queue::JobStatus::Pending,
            Time.utc
          )
        }
        inserted_count = @context.queue.push jobs
        send_json env, {
          "success": inserted_count,
          "fail":    jobs.size - inserted_count,
        }.to_json
      rescue e
        send_json env, {
          "success" => false,
          "error"   => e.message,
        }.to_json
      end
    end

    Koa.describe "Returns the image dimention of all pages in an entry"
    Koa.path "tid", desc: "A title ID"
    Koa.path "eid", desc: "An entry ID"
    Koa.response 200, ref: "$dimensionResult"
    get "/api/dimensions/:tid/:eid" do |env|
      begin
        tid = env.params.url["tid"]
        eid = env.params.url["eid"]

        title = @context.library.get_title tid
        raise "Title ID `#{tid}` not found" if title.nil?
        entry = title.get_entry eid
        raise "Entry ID `#{eid}` of `#{title.title}` not found" if entry.nil?

        sizes = entry.page_dimensions
        send_json env, {
          "success"    => true,
          "dimensions" => sizes,
        }.to_json
      rescue e
        send_json env, {
          "success" => false,
          "error"   => e.message,
        }.to_json
      end
    end

    Koa.describe "Downloads an entry"
    Koa.path "tid", desc: "A title ID"
    Koa.path "eid", desc: "An entry ID"
    Koa.response 200, ref: "$binary"
    Koa.response 404, "Entry not found"
    get "/api/download/:tid/:eid" do |env|
      begin
        title = (@context.library.get_title env.params.url["tid"]).not_nil!
        entry = (title.get_entry env.params.url["eid"]).not_nil!

        send_attachment env, entry.zip_path
      rescue e
        @context.error e
        env.response.status_code = 404
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
