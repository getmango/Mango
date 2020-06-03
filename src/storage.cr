require "sqlite3"
require "crypto/bcrypt"
require "uuid"
require "base64"
require "./util"

def hash_password(pw)
  Crypto::Bcrypt::Password.create(pw).to_s
end

def verify_password(hash, pw)
  (Crypto::Bcrypt::Password.new hash).verify pw
end

class Storage
  @path : String

  def self.default : self
    unless @@default
      @@default = new
    end
    @@default.not_nil!
  end

  def initialize(db_path : String? = nil, init_user = true)
    @path = db_path || Config.current.db_path
    dir = File.dirname @path
    unless Dir.exists? dir
      Logger.info "The DB directory #{dir} does not exist. " \
                  "Attepmting to create it"
      Dir.mkdir_p dir
    end
    DB.open "sqlite3://#{@path}" do |db|
      begin
        # We create the `ids` table first. even if the uses has an
        #   early version installed and has the `user` table only,
        #   we will still be able to create `ids`
        db.exec "create table ids" \
                "(path text, id text, is_title integer)"
        db.exec "create unique index path_idx on ids (path)"
        db.exec "create unique index id_idx on ids (id)"

        db.exec "create table users" \
                "(username text, password text, token text, admin integer)"
      rescue e
        unless e.message.not_nil!.ends_with? "already exists"
          Logger.fatal "Error when checking tables in DB: #{e}"
          raise e
        end

        # If the DB is initialized through CLI but no user is added, we need
        #   to create the admin user when first starting the app
        user_count = db.query_one "select count(*) from users", as: Int32
        init_admin if init_user && user_count == 0
      else
        Logger.debug "Creating DB file at #{@path}"
        db.exec "create unique index username_idx on users (username)"
        db.exec "create unique index token_idx on users (token)"

        init_admin if init_user
      end
    end
  end

  macro init_admin
    random_pw = random_str
    hash = hash_password random_pw
    db.exec "insert into users values (?, ?, ?, ?)",
      "admin", hash, nil, 1
    Logger.log "Initial user created. You can log in with " \
               "#{{"username" => "admin", "password" => random_pw}}"
  end

  def verify_user(username, password)
    DB.open "sqlite3://#{@path}" do |db|
      begin
        hash, token = db.query_one "select password, token from " \
                                   "users where username = (?)",
          username, as: {String, String?}
        unless verify_password hash, password
          Logger.debug "Password does not match the hash"
          return nil
        end
        Logger.debug "User #{username} verified"
        return token if token
        token = random_str
        Logger.debug "Updating token for #{username}"
        db.exec "update users set token = (?) where username = (?)",
          token, username
        return token
      rescue e
        Logger.error "Error when verifying user #{username}: #{e}"
        return nil
      end
    end
  end

  def verify_token(token)
    username = nil
    DB.open "sqlite3://#{@path}" do |db|
      begin
        username = db.query_one "select username from users where " \
                                "token = (?)", token, as: String
      rescue e
        Logger.debug "Unable to verify token"
      end
    end
    username
  end

  def verify_admin(token)
    is_admin = false
    DB.open "sqlite3://#{@path}" do |db|
      begin
        is_admin = db.query_one "select admin from users where " \
                                "token = (?)", token, as: Bool
      rescue e
        Logger.debug "Unable to verify user as admin"
      end
    end
    is_admin
  end

  def list_users
    results = Array(Tuple(String, Bool)).new
    DB.open "sqlite3://#{@path}" do |db|
      db.query "select username, admin from users" do |rs|
        rs.each do
          results << {rs.read(String), rs.read(Bool)}
        end
      end
    end
    results
  end

  def new_user(username, password, admin)
    validate_username username
    validate_password password
    admin = (admin ? 1 : 0)
    DB.open "sqlite3://#{@path}" do |db|
      hash = hash_password password
      db.exec "insert into users values (?, ?, ?, ?)",
        username, hash, nil, admin
    end
  end

  def update_user(original_username, username, password, admin)
    admin = (admin ? 1 : 0)
    validate_username username
    validate_password password unless password.empty?
    DB.open "sqlite3://#{@path}" do |db|
      if password.empty?
        db.exec "update users set username = (?), admin = (?) " \
                "where username = (?)",
          username, admin, original_username
      else
        hash = hash_password password
        db.exec "update users set username = (?), admin = (?)," \
                "password = (?) where username = (?)",
          username, admin, hash, original_username
      end
    end
  end

  def delete_user(username)
    DB.open "sqlite3://#{@path}" do |db|
      db.exec "delete from users where username = (?)", username
    end
  end

  def logout(token)
    DB.open "sqlite3://#{@path}" do |db|
      begin
        db.exec "update users set token = (?) where token = (?)", nil, token
      rescue
      end
    end
  end

  def get_id(path, is_title)
    id = random_str
    DB.open "sqlite3://#{@path}" do |db|
      begin
        id = db.query_one "select id from ids where path = (?)", path,
          as: {String}
      rescue
        db.exec "insert into ids values (?, ?, ?)", path, id, is_title ? 1 : 0
      end
    end
    id
  end

  def to_json(json : JSON::Builder)
    json.string self
  end
end
