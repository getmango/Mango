require "zip"
require "mime"

class Image
	property data : Bytes
	property mime : String
	property filename : String
	property size : Int32
	def initialize(@data, @mime, @filename, @size)
	end
end

class Entry
	property zip_path : String
	property title : String
	property size : String

	def initialize(path : String)
		@zip_path = path
		@title = File.basename path, ".zip"
		@size = (File.size path).humanize_bytes
	end
	def read_page(page_num)
		Zip::File.open @zip_path do |file|
			page = file.entries
				.select { |e|
					["image/jpeg", "image/png"].includes? \
					MIME.from_filename? e.filename
				}
				.sort { |a, b| a.filename <=> b.filename }
				.[page_num]
			page.open do |io|
				slice = Bytes.new page.uncompressed_size
				bytes_read = io.read_fully? slice
				unless bytes_read
					return nil
				end
				return Image.new slice, MIME.from_filename(page.filename),\
					page.filename, bytes_read
			end
		end
	end
	def get_cover()
		read_page 0
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
	def get_cover()
		@entries[0].get_cover
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
