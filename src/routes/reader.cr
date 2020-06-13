require "./router"

class ReaderRouter < Router
  def initialize
    get "/reader/:title/:entry" do |env|
      begin
        title = (@context.library.get_title env.params.url["title"]).not_nil!
        entry = (title.get_entry env.params.url["entry"]).not_nil!

        # load progress
        username = get_username env
        page = entry.load_progress username
        # we go back 2 * `IMGS_PER_PAGE` pages. the infinite scroll
        #   library perloads a few pages in advance, and the user
        #   might not have actually read them
        page = [page - 2 * IMGS_PER_PAGE, 1].max

        redirect env, "/reader/#{title.id}/#{entry.id}/#{page}"
      rescue e
        @context.error e
        env.response.status_code = 404
      end
    end

    get "/reader/:title/:entry/:page" do |env|
      begin
        base_url = Config.current.base_url

        title = (@context.library.get_title env.params.url["title"]).not_nil!
        entry = (title.get_entry env.params.url["entry"]).not_nil!
        page = env.params.url["page"].to_i
        raise "" if page > entry.pages || page <= 0

        # save progress
        username = get_username env
        entry.save_progress username, page

        pages = (page...[entry.pages + 1, page + IMGS_PER_PAGE].min)
        urls = pages.map { |idx|
          "#{base_url}api/page/#{title.id}/#{entry.id}/#{idx}"
        }
        reader_urls = pages.map { |idx|
          "#{base_url}reader/#{title.id}/#{entry.id}/#{idx}"
        }
        next_page = page + IMGS_PER_PAGE
        next_url = next_entry_url = nil
        exit_url = "#{base_url}book/#{title.id}"
        next_entry = entry.next_entry
        unless next_page > entry.pages
          next_url = "#{base_url}reader/#{title.id}/#{entry.id}/#{next_page}"
        end
        unless next_entry.nil?
          next_entry_url = "#{base_url}reader/#{title.id}/#{next_entry.id}"
        end

        render "src/views/reader.ecr"
      rescue e
        @context.error e
        env.response.status_code = 404
      end
    end
  end
end
