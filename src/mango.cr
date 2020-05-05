require "./config"
require "./server"
require "./mangadex/*"
require "option_parser"

VERSION = "0.3.0"

config_path = nil

OptionParser.parse do |parser|
  parser.banner = "Mango e-manga server/reader. Version #{VERSION}\n"

  parser.on "-v", "--version", "Show version" do
    puts "Version #{VERSION}"
    exit
  end
  parser.on "-h", "--help", "Show help" do
    puts parser
    exit
  end
  parser.on "-c PATH", "--config=PATH",
    "Path to the config file. " \
    "Default is `~/.config/mango/config.yml`" do |path|
    config_path = path
  end
end

Config.load(config_path).set_current

server = Server.new
server.start
