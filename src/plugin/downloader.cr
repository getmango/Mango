class Plugin
  class Downloader < Queue::Downloader
    use_default

    def initialize
      super
    end
  end
end
