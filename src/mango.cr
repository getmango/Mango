require "./config"
require "./server"
require "./mangadex/*"
require "option_parser"
require "clim"

MANGO_VERSION = "0.4.0"

macro common_option
  option "-c PATH", "--config=PATH", type: String,
    desc: "Path to the config file"
end

macro throw(msg)
  puts "ERROR: #{{{msg}}}"
  puts
  puts "Please see the `--help`."
  exit 1
end

class CLI < Clim
  main do
    desc "Mango - Manga Server and Web Reader. Version #{MANGO_VERSION}"
    usage "mango [sub_command] [options]"
    help short: "-h"
    version "Version #{MANGO_VERSION}", short: "-v"
    common_option
    run do |opts|
      Config.load(opts.config).set_current
      MangaDex::Downloader.default

      server = Server.new
      server.start
    end

    sub "admin" do
      desc "Run admin tools"
      usage "mango admin [tool]"
      help short: "-h"
      run do |opts|
        puts opts.help_string
      end
      sub "user" do
        desc "User management tool"
        usage "mango admin user [arguments] [options]"
        help short: "-h"
        argument "action", type: String,
          desc: "Action to make. Can be add/delete/update", required: true
        argument "username", type: String,
          desc: "Username to update or delete"
        option "-u USERNAME", "--username=USERNAME", type: String,
          desc: "Username"
        option "-p PASSWORD", "--password=PASSWORD", type: String,
          desc: "Password"
        option "--admin", desc: "Admin flag", type: Bool, default: false
        common_option
        run do |opts, args|
          Config.load(opts.config).set_current

          case args.action
          when "add"
            throw "Options `-u` and `-p` required." if opts.username.nil? ||
                                                       opts.password.nil?
          when "delete"
            throw "Argument `username` required." if args.username.nil?
          when "update"
            throw "Argument `username` required." if args.username.nil?
          else
            throw "Unknown action \"#{args.action}\"."
          end
        end
      end
    end
  end
end

CLI.start(ARGV)
