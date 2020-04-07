require "spec"
require "../src/context"
require "../src/server"

class State
	@@hash = {} of String => String

	def self.get(key)
		@@hash[key]?
	end

	def self.get!(key)
		@@hash[key]
	end

	def self.set(key, value)
		return if value.nil?
		@@hash[key] = value
	end

	def self.reset
		@@hash.clear
	end
end

def get_tempfile(name)
	path = State.get name
	if path.nil? || !File.exists? path
		file = File.tempfile name
		State.set name, file.path
		return file
	else
		return File.new path
	end
end

def with_default_config
	temp_config = get_tempfile "mango-test-config"
	config = Config.load temp_config.path
	logger = Logger.new config.log_level
	yield config, logger, temp_config.path
	temp_config.delete
end

def with_storage
	with_default_config do |config, logger|
		temp_db = get_tempfile "mango-test-db"
		storage = Storage.new temp_db.path, logger
		clear = yield storage, temp_db.path
		if clear == true
			temp_db.delete
		end
	end
end

def with_queue
	with_default_config do |config, logger|
		temp_queue_db = get_tempfile "mango-test-queue-db"
		queue = MangaDex::Queue.new temp_queue_db.path, logger
		clear = yield queue, temp_queue_db.path
		if clear == true
			temp_queue_db.delete
		end
	end
end
