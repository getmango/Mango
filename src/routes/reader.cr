struct ReaderRouter
  def initialize
    get "/reader/:title/:entry" do |env|
      begin
        username = get_username env

        title = (Library.default.get_title env.params.url["title"]).not_nil!
        entry = (title.get_entry env.params.url["entry"]).not_nil!

        next layout "reader-error" if entry.err_msg

        # load progress
        page_idx = [1, entry.load_progress username].max

        # start from page 1 if the user has finished reading the entry
        page_idx = 1 if entry.finished? username

        redirect env, "/reader/#{title.id}/#{entry.id}/#{page_idx}"
      rescue e
        Logger.error e
        env.response.status_code = 404
      end
    end

    get "/reader/:title/:entry/:page" do |env|
      begin
        base_url = Config.current.base_url

        username = get_username env

        title = (Library.default.get_title env.params.url["title"]).not_nil!
        entry = (title.get_entry env.params.url["entry"]).not_nil!
        page_idx = env.params.url["page"].to_i
        if page_idx > entry.pages || page_idx <= 0
          raise "Page #{page_idx} not found."
        end

        exit_url = "#{base_url}book/#{title.id}"

        next_entry_url = nil
        next_entry = entry.next_entry username
        unless next_entry.nil?
          next_entry_url = "#{base_url}reader/#{title.id}/#{next_entry.id}"
        end

        render "src/views/reader.html.ecr"
      rescue e
        Logger.error e
        env.response.status_code = 404
      end
    end
  end
end
