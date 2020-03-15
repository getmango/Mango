require "zip"
require "mime"
require "json"
require "uri"
require "./util"

struct Image
	property data : Bytes
	property mime : String
	property filename : String
	property size : Int32

	def initialize(@data, @mime, @filename, @size)
	end
end

class Entry
	property zip_path : String, book_title : String, title : String,
		size : String, pages : Int32, cover_url : String, id : String,
		title_id : String, encoded_path : String, encoded_title : String,
		mtime : Time

	def initialize(path, @book_title, @title_id, storage)
		@zip_path = path
		@encoded_path = URI.encode path
		@title = File.basename path, File.extname path
		@encoded_title = URI.encode @title
		@size = (File.size path).humanize_bytes
		file = Zip::File.new path
		@pages = file.entries
			.select { |e|
				["image/jpeg", "image/png"].includes? \
				MIME.from_filename? e.filename
			}
			.size
		file.close
		@id = storage.get_id @zip_path, false
		@cover_url = "/api/page/#{@title_id}/#{@id}/1"
		@mtime = File.info(@zip_path).modification_time
	end

	def to_json(json : JSON::Builder)
		json.object do
			{% for str in ["zip_path", "book_title", "title", "size",
				"cover_url", "id", "title_id", "encoded_path",
				"encoded_title"] %}
				json.field {{str}}, @{{str.id}}
			{% end %}
			json.field "pages" {json.number @pages}
			json.field "mtime" {json.number @mtime.to_unix}
		end
	end

	def read_page(page_num)
		Zip::File.open @zip_path do |file|
			page = file.entries
				.select { |e|
					["image/jpeg", "image/png"].includes? \
					MIME.from_filename? e.filename
				}
				.sort { |a, b|
					compare_alphanumerically a.filename, b.filename
				}
				.[page_num - 1]
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
	property dir : String, parent_id : String, title_ids : Array(String),
		entries : Array(Entry), title : String, id : String,
		encoded_title : String, mtime : Time

	def initialize(dir : String, @parent_id, storage,
				   @logger : MLogger, @library : Library)
		@dir = dir
		@id = storage.get_id @dir, true
		@title = File.basename dir
		@encoded_title = URI.encode @title
		@title_ids = [] of String
		@entries = [] of Entry

		Dir.entries(dir).each do |fn|
			next if fn.starts_with? "."
			path = File.join dir, fn
			if File.directory? path
				title = Title.new path, @id, storage, @logger, library
				next if title.entries.size == 0 && title.titles.size == 0
				@library.title_hash[title.id] = title
				@title_ids << title.id
				next
			end
			if [".zip", ".cbz"].includes? File.extname path
				next if !valid_zip path
				entry = Entry.new path, @title, @id, storage
				@entries << entry if entry.pages > 0
			end
		end

		@title_ids.sort! { |a,b|
			@library.title_hash[a].title <=> @library.title_hash[b].title
		}
		@entries.sort! { |a,b| a.title <=> b.title }

		mtimes = [File.info(dir).modification_time]
		mtimes += @title_ids.map{|e| @library.title_hash[e].mtime}
		mtimes += @entries.map{|e| e.mtime}
		@mtime = mtimes.max
	end

	def to_json(json : JSON::Builder)
		json.object do
			{% for str in ["dir", "title", "id", "encoded_title"] %}
				json.field {{str}}, @{{str.id}}
			{% end %}
			json.field "mtime" {json.number @mtime.to_unix}
			json.field "titles" do
				json.raw self.titles.to_json
			end
			json.field "entries" do
				json.raw @entries.to_json
			end
			json.field "parents" do
				json.array do
					self.parents.each do |title|
						json.object do
							json.field "title", title.title
							json.field "id", title.id
						end
					end
				end
			end
		end
	end

	def titles
		@title_ids.map {|tid| @library.get_title! tid}
	end

	def parents
		ary = [] of Title
		tid = @parent_id
		while !tid.empty?
			title = @library.get_title! tid
			ary << title
			tid = title.parent_id
		end
		ary
	end

	def size
		@entries.size + @title_ids.size
	end

	# When downloading from MangaDex, the zip/cbz file would not be valid
	#	before the download is completed. If we scan the zip file,
	#	Entry.new would throw, so we use this method to check before
	#	constructing Entry
	private def valid_zip(path : String)
		begin
			file = Zip::File.new path
			file.close
			return true
		rescue
			@logger.warn "File #{path} is corrupted or is not a valid zip "\
				"archive. Ignoring it."
			return false
		end
	end
	def get_entry(eid)
		@entries.find { |e| e.id == eid }
	end
	# For backward backward compatibility with v0.1.0, we save entry titles
	#	instead of IDs in info.json
	def save_progress(username, entry, page)
		info = TitleInfo.new @dir
		if info.progress[username]?.nil?
			info.progress[username] = {entry => page}
			info.save @dir
			return
		end
		info.progress[username][entry] = page
		info.save @dir
	end
	def load_progress(username, entry)
		info = TitleInfo.new @dir
		if info.progress[username]?.nil?
			return 0
		end
		if info.progress[username][entry]?.nil?
			return 0
		end
		info.progress[username][entry]
	end
	def load_percetage(username, entry)
		info = TitleInfo.new @dir
		page = load_progress username, entry
		entry_obj = @entries.find{|e| e.title == entry}
		return 0 if entry_obj.nil?
		page / entry_obj.pages
	end
	def load_percetage(username)
		read_pages = total_pages = 0
		@entries.each do |e|
			read_pages += load_progress username, e.title
			total_pages += e.pages
		end
		read_pages / total_pages
	end
	def next_entry(current_entry_obj)
		idx = @entries.index current_entry_obj
		return nil if idx.nil? || idx == @entries.size - 1
		@entries[idx + 1]
	end
end

class TitleInfo
	# { user1: { entry1: 10, entry2: 0 } }
	include JSON::Serializable

	property comment = "Generated by Mango. DO NOT EDIT!"
	property progress : Hash(String, Hash(String, Int32))

	def initialize(title_dir)
		info = nil

		json_path = File.join title_dir, "info.json"
		if File.exists? json_path
			info = TitleInfo.from_json File.read json_path
		else
			info = TitleInfo.from_json "{\"progress\": {}}"
		end

		@progress = info.progress.clone
	end
	def save(title_dir)
		json_path = File.join title_dir, "info.json"
		File.write json_path, self.to_pretty_json
	end
end

class Library
	property dir : String, title_ids : Array(String), scan_interval : Int32,
		logger : MLogger, storage : Storage, title_hash : Hash(String, Title)

	def initialize(@dir, @scan_interval, @logger, @storage)
		# explicitly initialize @titles to bypass the compiler check. it will
		#	be filled with actual Titles in the `scan` call below
		@title_ids = [] of String
		@title_hash = {} of String => Title

		return scan if @scan_interval < 1
		spawn do
			loop do
				start = Time.local
				scan
				ms = (Time.local - start).total_milliseconds
				@logger.info "Scanned #{@title_ids.size} titles in #{ms}ms"
				sleep @scan_interval * 60
			end
		end
	end
	def titles
		@title_ids.map {|tid| self.get_title!(tid) }
	end
	def to_json(json : JSON::Builder)
		json.object do
			json.field "dir", @dir
			json.field "titles" do
				json.raw self.titles.to_json
			end
		end
	end
	def get_title(tid)
		@title_hash[tid]?
	end
	def get_title!(tid)
		@title_hash[tid]
	end
	def scan
		unless Dir.exists? @dir
			@logger.info "The library directory #{@dir} does not exist. " \
				"Attempting to create it"
			Dir.mkdir_p @dir
		end
		@title_ids.clear
		(Dir.entries @dir)
			.select { |fn| !fn.starts_with? "." }
			.map { |fn| File.join @dir, fn }
			.select { |path| File.directory? path }
			.map { |path| Title.new path, "", @storage, @logger, self }
			.select { |title| !(title.entries.empty? && title.titles.empty?) }
			.sort { |a, b| a.title <=> b.title }
			.each do |title|
				@title_hash[title.id] = title
				@title_ids << title.id
			end
		@logger.debug "Scan completed"
	end
end
