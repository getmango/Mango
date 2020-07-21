class Plugin
  class Downloader < Queue::Downloader
    @library_path : String = Config.current.library_path
    @downloading = false

    def self.default : self
      unless @@default
        @@default = new
      end
      @@default.not_nil!
    end

    def initialize
      @queue = Queue.default
      @queue << self
    end
  end
end
