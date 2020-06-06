require "./config"
require "./server"
require "./mangadex/*"
require "option_parser"
require "clim"

MANGO_VERSION = "0.6.0"

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

      # empty ARGV so it won't be passed to Kemal
      ARGV.clear
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
          desc: "Action to perform. Can be add/delete/update/list"
        argument "username", type: String,
          desc: "Username to update or delete"
        option "-u USERNAME", "--username=USERNAME", type: String,
          desc: "Username"
        option "-p PASSWORD", "--password=PASSWORD", type: String,
          desc: "Password"
        option "-a", "--admin", desc: "Admin flag", type: Bool, default: false
        common_option
        run do |opts, args|
          Config.load(opts.config).set_current
          storage = Storage.new nil, false

          case args.action
          when "add"
            throw "Options `-u` and `-p` required." if opts.username.nil? ||
                                                       opts.password.nil?
            storage.new_user opts.username.not_nil!,
              opts.password.not_nil!, opts.admin
          when "delete"
            throw "Argument `username` required." if args.username.nil?
            storage.delete_user args.username
          when "update"
            throw "Argument `username` required." if args.username.nil?
            username = opts.username || args.username
            password = opts.password || ""
            storage.update_user args.username, username.not_nil!,
              password.not_nil!, opts.admin
          when "list"
            users = storage.list_users
            name_length = users.map(&.[0].size).max? || 0
            l_cell_width = ["username".size, name_length].max
            r_cell_width = "admin access".size
            header = " #{"username".ljust l_cell_width} | admin access "
            puts "-" * header.size
            puts header
            puts "-" * header.size
            users.each do |name, admin|
              puts " #{name.ljust l_cell_width} | " \
                   "#{admin.to_s.ljust r_cell_width} "
            end
            puts "-" * header.size
          when nil
            puts opts.help_string
          else
            throw "Unknown action \"#{args.action}\"."
          end
        end
      end
    end
  end
end

CLI.start(ARGV)
