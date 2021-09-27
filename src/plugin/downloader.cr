class Plugin
  class Downloader < Queue::Downloader
    use_default

    def initialize
      super
    end

    def pop : Queue::Job?
      job = nil
      MainFiber.run do
        DB.open "sqlite3://#{@queue.path}" do |db|
          begin
            db.query_one "select * from queue where id like '%-%' " \
                         "and (status = 0 or status = 1) " \
                         "order by time limit 1" do |res|
              job = Queue::Job.from_query_result res
            end
          rescue
          end
        end
      end
      job
    end

    private def download(job : Queue::Job)
      @downloading = true
      @queue.set_status Queue::JobStatus::Downloading, job

      begin
        unless job.plugin_id
          raise "Job does not have a plugin ID specificed"
        end

        plugin = Plugin.new job.plugin_id.not_nil!
        info = plugin.select_chapter job.plugin_chapter_id.not_nil!

        pages = info["pages"].as_i

        manga_title = sanitize_filename job.manga_title
        chapter_title = sanitize_filename info["title"].as_s

        @queue.set_pages pages, job
        lib_dir = @library_path
        manga_dir = File.join lib_dir, manga_title
        unless File.exists? manga_dir
          Dir.mkdir_p manga_dir
        end

        zip_path = File.join manga_dir, "#{chapter_title}.cbz.part"
        writer = Compress::Zip::Writer.new zip_path
      rescue e
        @queue.set_status Queue::JobStatus::Error, job
        unless e.message.nil?
          @queue.add_message e.message.not_nil!, job
        end
        @downloading = false
        raise e
      end

      fail_count = 0

      while page = plugin.next_page
        break unless @queue.exists? job

        fn = sanitize_filename page["filename"].as_s
        url = page["url"].as_s
        headers = HTTP::Headers.new

        if page["headers"]?
          page["headers"].as_h.each do |k, v|
            headers.add k, v.as_s
          end
        end

        page_success = false
        tries = 4

        loop do
          sleep plugin.info.wait_seconds.seconds
          Logger.debug "downloading #{url}"
          tries -= 1

          begin
            HTTP::Client.get url, headers do |res|
              unless res.success?
                raise "Failed to download page #{url}. " \
                      "[#{res.status_code}] #{res.status_message}"
              end
              writer.add fn, res.body_io
            end
          rescue e
            @queue.add_fail job
            fail_count += 1
            msg = "Failed to download page #{url}. Error: #{e}"
            @queue.add_message msg, job
            Logger.error msg
            Logger.debug "[failed] #{url}"
          else
            @queue.add_success job
            Logger.debug "[success] #{url}"
            page_success = true
          end

          break if page_success || tries < 0
        end
      end

      unless @queue.exists? job
        Logger.debug "Download cancelled"
        @downloading = false
        return
      end

      Logger.debug "Download completed. #{fail_count}/#{pages} failed"
      writer.close
      filename = File.join File.dirname(zip_path), File.basename(zip_path,
        ".part")
      File.rename zip_path, filename
      Logger.debug "cbz File created at #{filename}"

      zip_exception = validate_archive filename
      if !zip_exception.nil?
        @queue.add_message "The downloaded archive is corrupted. " \
                           "Error: #{zip_exception}", job
        @queue.set_status Queue::JobStatus::Error, job
      elsif fail_count > 0
        @queue.set_status Queue::JobStatus::MissingPages, job
      else
        @queue.set_status Queue::JobStatus::Completed, job
      end

      @downloading = false
    end
  end
end
