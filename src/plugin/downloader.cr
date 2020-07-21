class Plugin
  class Downloader < Queue::Downloader
    use_default

    def initialize
      super
    end

    def pop : Queue::Job?
      job = nil
      DB.open "sqlite3://#{@queue.path}" do |db|
        begin
          db.query_one "select * from queue where id like '%-%' and " \
                       "(status = 0 or status = 1) order by time limit 1" \
                       do |res|
            job = Queue::Job.from_query_result res
          end
        rescue
        end
      end
      job
    end
  end
end
