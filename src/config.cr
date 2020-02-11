require "yaml"
require "uuid"
require "base64"

class Config
	include YAML::Serializable

	@[YAML::Field(key: "port")]
	property port = 9000

	@[YAML::Field(key: "library_path")]
	property library_path = File.expand_path "~/mango-library", home: true

	@[YAML::Field(key: "db_path")]
	property db_path = File.expand_path "~/mango-library/mango.db", home: true

	def self.load
		cfg_path = File.expand_path "~/.config/mango/config.yml", home: true
		if File.exists? cfg_path
			return self.from_yaml File.read cfg_path
		end
		puts "The config file #{cfg_path} does not exist." \
			"Do you want mango to dump the default config there? [Y/n]"
		input = gets
		if !input.nil? && input.downcase == "n"
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
