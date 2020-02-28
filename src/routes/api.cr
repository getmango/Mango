require "./router"
require "../mangadex/*"

class APIRouter < Router
	def setup
		get "/api/page/:tid/:eid/:page" do |env|
			begin
				tid = env.params.url["tid"]
				eid = env.params.url["eid"]
				page = env.params.url["page"].to_i

				title = @context.library.get_title tid
				raise "Title ID `#{tid}` not found" if title.nil?
				entry = title.get_entry eid
				raise "Entry ID `#{eid}` of `#{title.title}` not found" if \
					entry.nil?
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

		get "/api/book/:title" do |env|
			begin
				tid = env.params.url["tid"]
				title = @context.library.get_title tid
				raise "Title ID `#{tid}` not found" if title.nil?

				send_json env, title.to_json
			rescue e
				@context.error e
				env.response.status_code = 500
				e.message
			end
		end

		get "/api/book" do |env|
			send_json env, @context.library.to_json
		end

		post "/api/admin/scan" do |env|
			start = Time.utc
			@context.library.scan
			ms = (Time.utc - start).total_milliseconds
			send_json env, {
				"milliseconds" => ms,
				"titles" => @context.library.titles.size
			}.to_json
		end

		post "/api/admin/user/delete/:username" do |env|
			begin
				username = env.params.url["username"]
				@context.storage.delete_user username
			rescue e
				@context.error e
				send_json env, {
					"success" => false,
					"error" => e.message
				}.to_json
			else
				send_json env, {"success" => true}.to_json
			end
		end

		post "/api/progress/:title/:entry/:page" do |env|
			begin
				username = get_username env
				title = (@context.library.get_title env.params.url["title"])
					.not_nil!
				entry = (title.get_entry env.params.url["entry"]).not_nil!
				page = env.params.url["page"].to_i

				raise "incorrect page value" if page < 0 || page > entry.pages
				title.save_progress username, entry.title, page
			rescue e
				@context.error e
				send_json env, {
					"success" => false,
					"error" => e.message
				}.to_json
			else
				send_json env, {"success" => true}.to_json
			end
		end

		get "/api/admin/mangadex/manga/:id" do |env|
			begin
				id = env.params.url["id"]
				api = MangaDex::API.new \
					@context.config.mangadex["api_url"].to_s
				manga = api.get_manga id
				send_json env, manga.to_info_json
			rescue e
				@context.error e
				send_json env, {"error" => e.message}.to_json
			end
		end

		post "/api/admin/mangadex/download" do |env|
			begin
				chapters = env.params.json["chapters"].as(Array).map{|c| c.as_h}
				queue = MangaDex::Queue.new \
					@context.config.mangadex["download_queue_db_path"].to_s
				jobs = chapters.map {|chapter|
					MangaDex::Job.new(
						chapter["id"].as_s,
						chapter["manga_id"].as_s,
						chapter["title"].as_s,
						chapter["manga_title"].as_s,
						MangaDex::JobStatus::Pending,
						"",
						Time.utc
					)
				}
				inserted_count = queue.push jobs
				send_json env, {
					"success": inserted_count,
					"fail": jobs.size - inserted_count
				}.to_json
			rescue e
				@context.error e
				send_json env, {"error" => e.message}.to_json
			end
		end
	end
end
