require "zip"

class Entry
	property zip_path : String
	property title : String
	property size : String

	def initialize(path : String)
		@zip_path = path
		@title = File.basename path, ".zip"
		@size = (File.size path).humanize_bytes
	end
end

class Title
	property dir : String
	property entries : Array(Entry)
	property title : String

	def initialize(dir : String)
		@dir = dir
		@title = File.basename dir
		@entries = (Dir.entries dir)
			.select! { |path| (File.extname path) == ".zip" }
			.map { |path| Entry.new File.join dir, path }
			.sort { |a, b| a.title <=> b.title }
	end
end

class Library
	property dir : String
	property titles : Array(Title)

	def initialize(dir : String)
		@dir = dir
		unless Dir.exists? dir
			abort "ERROR: The library directory #{dir} does not exist"
		end
		@titles = (Dir.entries dir)
			.select! { |path| File.directory? File.join dir, path }
			.map { |path| Title.new File.join dir, path }
			.select! { |title| !title.entries.empty? }
	end
end
