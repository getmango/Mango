require "./api"
require "sqlite3"

module MangaDex
	struct PageJob
		property success = false
		property url : String
		property filename : String
		property writer : Zip::Writer
		property tries_remaning : Int32
		def initialize(@url, @filename, @writer, @tries_remaning)
		end
	end
	enum JobStatus
		Pending     # 0
		Downloading # 1
		Error       # 2
		Completed   # 3
	end
	struct Job
		property id : String
		property manga_id : String
		property title : String
		property manga_title : String
		property status : JobStatus
		property log : String
		property time : Time
		private def load_query_result(res : DB::ResultSet)
			begin
				@id, @manga_id, @title, @manga_title, status, @log, time = \
					res.as {String, String, String, String, Int32, String, Int64}
				@status = JobStatus.new status
				@time = Time.unix time
				return true
			rescue e
				puts e
				return false
			end
		end
		def self.from_query_result(res : DB::ResultSet)
			job = Job.allocate
			success = job.load_query_result res
			return success ? job : nil
		end
		def initialize(@id, @manga_id, @title, @manga_title, @status, @log,
					   @time)
		end
	end
	class Queue
		def initialize(@path : String)
			dir = File.dirname path
			unless Dir.exists? dir
				puts "The queue DB directory #{dir} does not exist. " \
					"Attepmting to create it"
				Dir.mkdir_p dir
			end
			DB.open "sqlite3://#{@path}" do |db|
				begin
					db.exec "create table queue" \
						"(id string, manga_id string, title text," \
						"manga_title text, status integer, log text, time integer)"
					db.exec "create unique index id_idx on queue (id)"
					db.exec "create index manga_id_idx on queue (manga_id)"
					db.exec "create index status_idx on queue (status)"
				rescue e
					unless e.message == "table queue already exists"
						puts "Error when checking tables in DB: #{e}"
						raise e
					end
				end
			end
		end
		# Returns the earliest job in queue or nil if the job cannot be parsed.
		#	Raises DB::Error if queue is empty
		def pop
			DB.open "sqlite3://#{@path}" do |db|
				res = db.query_one "select * from queue where status = 0 "\
					"order by time limit 1"
				job = Job.from_query_result res
				db.exec "delete from queue where id = (select id from queue "\
					"where status = 0 order by time limit 1)"
				return job
			end
		end
		# Push an array of jobs into the queue, and return the number of jobs
		#	inserted. Any job already exists in the queue will be ignored.
		def push(jobs : Array(Job))
			start_count = self.count
			DB.open "sqlite3://#{@path}" do |db|
				jobs.each {|job|
					db.exec "insert or ignore into queue values "\
						"(?, ?, ?, ?, ?, ?, ?)",
						job.id, job.manga_id, job.title, job.manga_title,
						job.status.to_i, job.log, job.time.to_unix
				}
			end
			self.count - start_count
		end
		def delete(id)
			DB.open "sqlite3://#{@path}" do |db|
				db.exec "delete from queue where id = (?)", id
			end
		end
		def delete_status(status : JobStatus)
			DB.open "sqlite3://#{@path}" do |db|
				db.exec "delete from queue where status = (?)", status.to_i
			end
		end
		def count_status(status : JobStatus)
			DB.open "sqlite3://#{@path}" do |db|
				return db.query_one "select count(*) from queue where status = (?)",
					status.to_i, as: Int32
			end
		end
		def count
			DB.open "sqlite3://#{@path}" do |db|
				return db.query_one "select count(*) from queue", as: Int32
			end
		end
		def log(msg : String, job : Job)
			DB.open "sqlite3://#{@path}" do |db|
				db.exec "update queue set log = log || (?) || (?) where "\
					"id = (?)", msg, "\n", job.id
			end
		end
		def set_status(status : JobStatus, job : Job)
			DB.open "sqlite3://#{@path}" do |db|
				db.exec "update queue set status = (?) where id = (?)",
					status.to_i, job.id
			end
		end
		def get_all
			jobs = [] of Job
			DB.open "sqlite3://#{@path}" do |db|
				jobs = db.query_all "select * from queue", do |rs|
					Job.from_query_result rs
				end
			end
			return jobs
		end
	end

	class Downloader
		@stopped = false

		def initialize(@queue : Queue, @api : API, @library_path : String,
					   @wait_seconds : Int32, @retries : Int32)
			spawn do
				loop do
					sleep 1.second
					next if @stopped
					begin
						job = @queue.pop
						next if job.nil?
						download job
					end
				end
			end
		end

		def stop
			@stopped = true
		end
		def resume
			@stopped = false
		end

		private def download(job : Job)
			self.stop
			@queue.set_status JobStatus::Downloading, job
			chapter = @api.get_chapter(job.id)
			lib_dir = @library_path
			manga_dir = File.join lib_dir, chapter.manga.title
			unless File.exists? manga_dir
				Dir.mkdir_p manga_dir
			end
			zip_path = File.join manga_dir, "#{job.title}.cbz"
			@queue.log "Downloading to #{zip_path}", job

			# Find the number of digits needed to store the number of pages
			len = Math.log10(chapter.pages.size).to_i + 1

			writer = Zip::Writer.new zip_path
			# Create a buffered channel. It works as an FIFO queue
			channel = Channel(PageJob).new chapter.pages.size
			spawn do
				chapter.pages.each_with_index do |tuple, i|
					fn, url = tuple
					ext = File.extname fn
					fn = "#{i.to_s.rjust len, '0'}#{ext}"
					page_job = PageJob.new url, fn, writer, @retries
					puts "Downloading #{url}"
					@queue.log "Downloading #{url}", job
					loop do
						sleep @wait_seconds.seconds
						download_page page_job
						break if page_job.success ||
							page_job.tries_remaning <= 0
						page_job.tries_remaning -= 1
						puts "Retrying... Remaining retries: "\
							"#{page_job.tries_remaning}"
						@queue.log "Retrying. Remaining retries: #{page_job.tries_remaning}", job
					end

					channel.send page_job
				end
			end

			spawn do
				page_jobs = [] of PageJob
				chapter.pages.size.times do
					page_job = channel.receive
					log_str = "[#{page_job.success ? "success" : "failed"}] #{page_job.url}"
					puts log_str
					@queue.log log_str, job
					page_jobs << page_job
				end
				fail_count = page_jobs.select{|j| !j.success}.size
				log_str = "Download completed. "\
					"#{fail_count}/#{page_jobs.size} failed"
				puts log_str
				@queue.log log_str, job
				writer.close
				puts "cbz File created at #{zip_path}"
				if fail_count == 0
					@queue.set_status JobStatus::Completed, job
				else
					@queue.set_status JobStatus::MissingPages, job
				end
				self.resume
			end
		end

		private def download_page(job : PageJob)
			headers = HTTP::Headers {
				"User-agent" => "Mangadex.cr"
			}
			begin
				HTTP::Client.get job.url, headers do |res|
					return if !res.success?
					job.writer.add job.filename, res.body_io
				end
				job.success = true
			rescue e
				puts e
				job.success = false
			end
		end
	end
end
