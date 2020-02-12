require "zip"
require "mime"
require "json"

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
	property book_title : String
	property title : String
	property size : String
	property pages : Int32
	property cover_url : String

	JSON.mapping zip_path: String, book_title: String, title: String, \
		size: String, pages: Int32, cover_url: String

	def initialize(path, @book_title)
		@zip_path = path
		@title = File.basename path, ".zip"
		@size = (File.size path).humanize_bytes
		@pages = Zip::File.new(path).entries.size
		@cover_url = "/api/page/#{@book_title}/#{title}/0"
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
end

class Title
	JSON.mapping dir: String, entries: Array(Entry), title: String

	def initialize(dir : String)
		@dir = dir
		@title = File.basename dir
		@entries = (Dir.entries dir)
			.select! { |path| (File.extname path) == ".zip" }
			.map { |path| Entry.new File.join(dir, path), @title }
			.sort { |a, b| a.title <=> b.title }
	end
	def get_entry(name)
		@entries.find { |e| e.title == name }
	end

end

class Library
	JSON.mapping dir: String, titles: Array(Title)

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
	def get_title(name)
		@titles.find { |t| t.title == name }
	end
end
