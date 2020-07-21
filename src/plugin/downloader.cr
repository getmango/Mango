class Plugin
  class Downloader < Queue::Downloader

    def self.default : self
      unless @@default
        @@default = new
      end
      @@default.not_nil!
    end

    def initialize
      super
    end
  end
end
