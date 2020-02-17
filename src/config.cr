require "yaml"

class Config
	include YAML::Serializable

	@[YAML::Field(key: "port")]
	property port : Int32 = 9000

	@[YAML::Field(key: "library_path")]
	property library_path : String = \
		File.expand_path "~/mango/library", home: true

	@[YAML::Field(key: "db_path")]
	property db_path : String = \
		File.expand_path "~/mango/mango.db", home: true

	@[YAML::Field(key: "scan_interval_minutes")]
	property scan_interval : Int32 = 5

	@[YAML::Field(key: "log_level")]
	property log_level : String = "info"

	def self.load(path : String?)
		path = "~/.config/mango/config.yml" if path.nil?
		cfg_path = File.expand_path path, home: true
		if File.exists? cfg_path
			return self.from_yaml File.read cfg_path
		end
		puts "The config file #{cfg_path} does not exist." \
			" Do you want mango to dump the default config there? [Y/n]"
		input = gets
		if input && input.downcase == "n"
			abort "Aborting..."
		end
		default = self.allocate
		cfg_dir = File.dirname cfg_path
		unless Dir.exists? cfg_dir
			Dir.mkdir_p cfg_dir
		end
		File.write cfg_path, default.to_yaml
		puts "The config file has been created at #{cfg_path}."
		default
	end
end
