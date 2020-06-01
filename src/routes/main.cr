require "./router"

class MainRouter < Router
  def setup
    get "/login" do |env|
      render "src/views/login.ecr"
    end

    get "/logout" do |env|
      begin
        cookie = env.request.cookies.find { |c| c.name == "token" }.not_nil!
        @context.storage.logout cookie.value
      rescue e
        @context.error "Error when attempting to log out: #{e}"
      ensure
        env.redirect "/login"
      end
    end

    post "/login" do |env|
      begin
        username = env.params.body["username"]
        password = env.params.body["password"]
        token = @context.storage.verify_user(username, password).not_nil!

        cookie = HTTP::Cookie.new "token", token
        cookie.expires = Time.local.shift years: 1
        env.response.cookies << cookie
        env.redirect "/"
      rescue
        env.redirect "/login"
      end
    end

    get "/library" do |env|
      begin
        titles = @context.library.titles
        username = get_username env
        percentage = titles.map &.load_percentage username
        layout "library"
      rescue e
        @context.error e
        env.response.status_code = 500
      end
    end

    get "/book/:title" do |env|
      begin
        title = (@context.library.get_title env.params.url["title"]).not_nil!
        username = get_username env
        percentage = title.entries.map { |e|
          title.load_percentage username, e.title
        }
        layout "title"
      rescue e
        @context.error e
        env.response.status_code = 404
      end
    end

    get "/download" do |env|
      base_url = @context.config.mangadex["base_url"]
      layout "download"
    end

    get "/" do |env|
      begin
        titles = @context.library.titles
        username = get_username env

        # map: get the on-deck entry or nil for each Title
        # select: select only entries (and ignore Nil's) from the array
        #   produced by map
        continue_reading_entries = titles.map { |t|
          t.get_continue_reading_entry username
        }.select Entry

        percentage = continue_reading_entries.map { |e|
          e.book.load_percentage username, e.title
        }

        last_read = continue_reading_entries.map { |e|
          e.book.get_last_read_for_continue_reading username, e
        }

        # Group values in a NamedTuple for easier sorting
        cr_entries = continue_reading_entries.map_with_index { |e, i|
          {
            entry: e,
            percentage: percentage[i],
            # if you're ok with the NamedTuple approach we could remove the
            # percentage and last_read vars above and just call the methods 
            # here eg.
            # perecentage: e.book.load_percentage username, e.title
            last_read: last_read[i]
          }
        }
        # I couldn't get the sort to work where last_read type is `Time | Nil`
        # so I'm creating a new variable with just the entries that have last_read
        # even still, I have to do another workaround within the sort below :/
        cr_entries_not_nil = cr_entries.select { |e| e[:last_read] }
        cr_entries_not_nil.sort! { |a, b| 
          # 'if' ensures values aren't nil otherwise the compiler errors
          # because it still thinks the NamedTuple `last_read` can be nil
          # even though we only 'select'ed the objects which have last_read
          # there's probably a better way to do this
          if (a_time = a[:last_read]) && (b_time = b[:last_read])
            b_time <=> a_time
          end
        }
        # add `last_read == nil` entries AFTER sorted entries
        continue_reading = cr_entries_not_nil + cr_entries.select { |e| e[:last_read].nil? }

        layout "home"
      rescue e
        @context.error e
        env.response.status_code = 500
      end
    end
  end
end
