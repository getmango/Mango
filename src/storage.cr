require "sqlite3"
require "crypto/bcrypt"
require "uuid"
require "base64"

def hash_password(pw)
	Crypto::Bcrypt::Password.create(pw).to_s
end

def verify_password(hash, pw)
	(Crypto::Bcrypt::Password.new hash).verify pw
end

def random_str()
	Base64.strict_encode UUID.random().to_s
end

class Storage
	property path : String

	def initialize(path)
		@path = path
		DB.open "sqlite3://#{path}" do |db|
			begin
				db.exec "create table users" \
					"(username text, password text, token text, admin integer)"
			rescue e : SQLite3::Exception | DB::Error
				unless e.message == "table users already exists"
					raise e
				end
			else
				db.exec "create unique index username_idx on users (username)"
				db.exec "create unique index token_idx on users (token)"
				random_pw = random_str
				hash = hash_password random_pw
				db.exec "insert into users values (?, ?, ?, ?)",
					"admin", hash, "", 1
				puts "Initial user created. You can log in with " \
					"#{{"username" => "admin", "password" => random_pw}}"
			end
		end
	end

	def verify_user(username, password)
		DB.open "sqlite3://#{@path}" do |db|
			begin
				hash = db.query_one "select password from users where " \
					"username = (?)", username, as: String
				unless verify_password hash, password
					return nil
				end
				token = random_str
				db.exec "update users set token = (?) where username = (?)",
					token, username
				return token
			rescue e : SQLite3::Exception | DB::Error
				return nil
			end
		end
	end

	def verify_token(token)
		DB.open "sqlite3://#{@path}" do |db|
			begin
				username = db.query_one "select username from users where " \
					"token = (?)", token, as: String
				return username
			rescue e : SQLite3::Exception | DB::Error
				return nil
			end
		end
	end
end
