require "./router"

class ReaderRouter < Router
	def setup
		get "/reader/:title/:entry" do |env|
			begin
				title = (@context.library.get_title env.params.url["title"])
					.not_nil!
				entry = (title.get_entry env.params.url["entry"]).not_nil!

				# load progress
				username = get_username env
				page = title.load_progress username, entry.title
				# we go back 2 * `IMGS_PER_PAGE` pages. the infinite scroll
				# 	library perloads a few pages in advance, and the user
				# 	might not have actually read them
				page = [page - 2 * IMGS_PER_PAGE, 1].max

				env.redirect "/reader/#{title.id}/#{entry.id}/#{page}"
			rescue e
				@context.error e
				env.response.status_code = 404
			end
		end

		get "/reader/:title/:entry/:page" do |env|
			begin
				title = (@context.library.get_title env.params.url["title"])
					.not_nil!
				entry = (title.get_entry env.params.url["entry"]).not_nil!
				page = env.params.url["page"].to_i
				raise "" if page > entry.pages || page <= 0

				# save progress
				username = get_username env
				title.save_progress username, entry.title, page

				pages = (page...[entry.pages + 1, page + IMGS_PER_PAGE].min)
				urls = pages.map { |idx|
					"/api/page/#{title.id}/#{entry.id}/#{idx}" }
				reader_urls = pages.map { |idx|
					"/reader/#{title.id}/#{entry.id}/#{idx}" }
				next_page = page + IMGS_PER_PAGE
				next_url = next_page > entry.pages ? nil :
					"/reader/#{title.id}/#{entry.id}/#{next_page}"
				exit_url = "/book/#{title.id}"
				next_entry = title.next_entry entry
				next_entry_url = next_entry.nil? ? nil : \
					"/reader/#{title.id}/#{next_entry.id}"

				render "src/views/reader.ecr"
			rescue e
				@context.error e
				env.response.status_code = 404
			end
		end
	end
end
