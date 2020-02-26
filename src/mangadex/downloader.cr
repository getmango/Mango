require "./api"
require "sqlite3"

module MangaDex
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
		def push(job)
			begin
				DB.open "sqlite3://#{@path}" do |db|
					db.exec "insert into queue values (?, ?, ?, ?, ?, ?, ?)",
						job.id, job.manga_id, job.title, job.manga_title,
						job.status.to_i, job.log, job.time.to_unix
				end
				return true
			rescue
				return false
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
		#def push(job)
			#sucess = false
			#DB.open "sqlite3://#{@path}" do |db|
				#trans = db.begin_transaction
				#con = trans.connection
				#begin
					#con.exec "insert into queue values (?, ?, ?, ?, ?, ?, ?)",
						#job.id, job.manga_id, job.title, job.manga_title,
						#job.status.to_i, job.log, job.time.to_unix
				#rescue
					#trans.rollback
				#else
					#trans.commit
					#success = true
				#end
				#con.close
				#trans.close
			#end
			#success
		#end
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
	end
end
