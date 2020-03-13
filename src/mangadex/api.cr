require "http/client"
require "json"
require "csv"

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

module MangaDex
	class Chapter
		string_properties ["lang_code", "title", "volume", "chapter"]
		property manga : Manga
		property time = Time.local
		property id : String
		property full_title = ""
		property language = ""
		property pages = [] of {String, String} # filename, url
		property groups = [] of {Int32, String} # group_id, group_name

		def initialize(@id, json_obj : JSON::Any, @manga, lang :
					   Hash(String, String))
			self.parse_json json_obj, lang
		end

		def to_info_json
			JSON.build do |json|
				json.object do
					{% for name in ["id", "title", "volume", "chapter",
							"language", "full_title"] %}
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
				@full_title = @title
				unless @chapter.empty?
					@full_title = "Ch.#{@chapter} " + @full_title
				end
				unless @volume.empty?
					@full_title = "Vol.#{@volume} " + @full_title
				end
			rescue e
				raise "failed to parse json: #{e}"
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
			if obj["status"]? != "OK"
				raise "Expecting `OK` in the `status` field. " \
					"Got `#{obj["status"]?}`"
			end
			begin
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

		def get_chapter(chapter : Chapter)
			obj = self.get File.join @base_url, "chapter/#{chapter.id}"
			if obj["status"]? == "external"
				raise "This chapter is hosted on an external site " \
					"#{obj["external"]?}, and Mango does not support " \
					"external chapters."
			end
			if obj["status"]? != "OK"
				raise "Expecting `OK` in the `status` field. " \
					"Got `#{obj["status"]?}`"
			end
			begin
				server = obj["server"].as_s
				hash = obj["hash"].as_s
				chapter.pages = obj["page_array"].as_a.map do |fn|
					{
						fn.as_s,
						"#{server}#{hash}/#{fn.as_s}"
					}
				end
			rescue
				raise "Failed to parse JSON"
			end
		end

		def get_chapter(id : String)
			obj = self.get File.join @base_url, "chapter/#{id}"
			if obj["status"]? == "external"
				raise "This chapter is hosted on an external site " \
					"#{obj["external"]?}, and Mango does not support " \
					"external chapters."
			end
			if obj["status"]? != "OK"
				raise "Expecting `OK` in the `status` field. " \
					"Got `#{obj["status"]?}`"
			end
			manga_id = ""
			begin
				manga_id = obj["manga_id"].as_i.to_s
			rescue
				raise "Failed to parse JSON"
			end
			manga = self.get_manga manga_id
			chapter = manga.chapters.find {|c| c.id == id}.not_nil!
			self.get_chapter chapter
			return chapter
		end
	end
end
