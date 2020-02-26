require "http/client"
require "json"
require "csv"
require "zip"

macro string_properties (names)
	{% for name in names %}
		property {{name.id}} = ""
	{% end %}
end

macro parse_strings_from_json (names)
	{% for name in names %}
		@{{name.id}} = obj[{{name}}].as_s
	{% end %}
end

module Mangadex
	class DownloadContext
		property success = false
		property url : String
		property filename : String
		property writer : Zip::Writer
		property tries_remaning : Int32
		def initialize(@url, @filename, @writer, @tries_remaning)
		end
	end
	class Chapter
		string_properties ["lang_code", "title", "volume", "chapter"]
		property manga : Manga
		property time = Time.local
		property id : String
		property language = ""
		property pages = [] of {String, String} # filename, url
		property groups = [] of {Int32, String} # group_id, group_name

		def initialize(@id, json_obj : JSON::Any, @manga, lang : Hash(String, String))
			self.parse_json json_obj, lang
		end
		def to_info_json
			JSON.build do |json|
				json.object do
					{% for name in ["id", "title", "volume", "chapter",
							"language"] %}
						json.field {{name}}, @{{name.id}}
					{% end %}
					json.field "time", @time.to_unix.to_s
					json.field "manga_title", @manga.title
					json.field "manga_id", @manga.id
					json.field "groups" do
						json.object do
							@groups.each do |gid, gname|
								json.field gname, gid
							end
						end
					end
				end
			end
		end
		def parse_json(obj, lang)
			begin
				parse_strings_from_json ["lang_code", "title", "volume",
							 "chapter"]
				language = lang[@lang_code]?
				@language = language if language
				@time = Time.unix obj["timestamp"].as_i
				suffixes = ["", "_2", "_3"]
				suffixes.each do |s|
					gid = obj["group_id#{s}"].as_i
					next if gid == 0
					gname = obj["group_name#{s}"].as_s
					@groups << {gid, gname}
				end
			rescue e
				raise "failed to parse json: #{e}"
			end
		end
		def download(dir, wait_seconds=5, retries=4)
			name = "mangadex-chapter-#{@id}"
			info_json_path = File.join dir, "#{name}.info.json"
			zip_path = File.join dir, "#{name}.cbz"

			puts "Writing info.josn to #{info_json_path}"
			File.write info_json_path, self.to_info_json

			writer = Zip::Writer.new zip_path

			# Create a buffered channel. It works as an FIFO queue
			channel = Channel(DownloadContext).new @pages.size

			spawn do
				@pages.each do |fn, url|
					context = DownloadContext.new url, fn, writer, retries

					puts "Downlaoding #{url}"
					loop do
						sleep wait_seconds.seconds
						download_page context
						break if context.success || context.tries_remaning <= 0
						context.tries_remaning -= 1
						puts "Retrying... Remaining retries: "\
							"#{context.tries_remaning}"
					end

					channel.send context
				end
			end

			spawn do
				context_ary = [] of DownloadContext
				@pages.size.times do
					context = channel.receive
					puts "[#{context.success}] #{context.url}"
					context_ary << context
				end
				fail_count = context_ary.select{|ctx| !ctx.success}.size
				puts "Download completed. "\
					"#{fail_count}/#{context_ary.size} failed"
				writer.close
				puts "cbz File created at #{zip_path}"
			end
		end
		def download_page(context)
			headers = HTTP::Headers {
				"User-agent" => "Mangadex.cr"
			}
			begin
				HTTP::Client.get context.url, headers do |res|
					return if !res.success?
					context.writer.add context.filename, res.body_io
				end
				context.success = true
			rescue e
				puts e
				context.success = false
			end
		end
	end
	class Manga
		string_properties ["cover_url", "description", "title", "author",
					"artist"]
		property chapters = [] of Chapter
		property id : String

		def initialize(@id, json_obj : JSON::Any)
			self.parse_json json_obj
		end
		def to_info_json(with_chapters = true)
			JSON.build do |json|
				json.object do
					{% for name in ["id", "title", "description",
							"author", "artist", "cover_url"] %}
						json.field {{name}}, @{{name.id}}
					{% end %}
					if with_chapters
						json.field "chapters" do
							json.array do
								@chapters.each do |c|
									json.raw c.to_info_json
								end
							end
						end
					end
				end
			end
		end
		def parse_json(obj)
			begin
				parse_strings_from_json ["cover_url", "description", "title",
							 "author", "artist"]
			rescue e
				raise "failed to parse json: #{e}"
			end
		end
	end
	class API
		def initialize(@base_url = "https://mangadex.org/api/")
			@lang = {} of String => String
			CSV.each_row {{read_file "src/assets/lang_codes.csv"}} do |row|
				@lang[row[1]] = row[0]
			end
		end
		def get(url)
			headers = HTTP::Headers {
				"User-agent" => "Mangadex.cr"
			}
			res = HTTP::Client.get url, headers
			raise "Failed to get #{url}. [#{res.status_code}] "\
				"#{res.status_message}" if !res.success?
			JSON.parse res.body
		end
		def get_manga(id)
			obj = self.get File.join @base_url, "manga/#{id}"
			begin
				raise "" if obj["status"] != "OK"
				manga = Manga.new id, obj["manga"]
				obj["chapter"].as_h.map do |k, v|
					chapter = Chapter.new k, v, manga, @lang
					manga.chapters << chapter
				end
				return manga
			rescue
				raise "Failed to parse JSON"
			end
		end
		def get_chapter(chapter)
			obj = self.get File.join @base_url, "chapter/#{chapter.id}"
			begin
				raise "" if obj["status"] != "OK"
				server = obj["server"].as_s
				hash = obj["hash"].as_s
				chapter.pages = obj["page_array"].as_a.map{|fn|
					{
						fn.as_s,
						"#{server}#{hash}/#{fn.as_s}"
					}
				}
			rescue
				raise "Failed to parse JSON"
			end
		end
	end
end
