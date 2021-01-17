require "sqlite3"
require "crypto/bcrypt"
require "uuid"
require "base64"
require "./util/*"
require "mg"
require "../migration/*"

def hash_password(pw)
  Crypto::Bcrypt::Password.create(pw).to_s
end

def verify_password(hash, pw)
  (Crypto::Bcrypt::Password.new hash).verify pw
end

class Storage
  @@insert_ids = [] of IDTuple

  @path : String
  @db : DB::Database?

  alias IDTuple = NamedTuple(path: String,
    id: String,
    is_title: Bool)

  use_default

  def initialize(db_path : String? = nil, init_user = true, *,
                 @auto_close = true)
    @path = db_path || Config.current.db_path
    dir = File.dirname @path
    unless Dir.exists? dir
      Logger.info "The DB directory #{dir} does not exist. " \
                  "Attepmting to create it"
      Dir.mkdir_p dir
    end
    MainFiber.run do
      DB.open "sqlite3://#{@path}" do |db|
        begin
          severity = Logger.get_severity
          Log.setup "mg", severity
          MG::Migration.new(db).migrate
        rescue e
          Logger.reset
          Logger.fatal "DB migration failed. #{e}"
          raise e
        else
          Logger.reset
        end

        user_count = db.query_one "select count(*) from users", as: Int32
        init_admin if init_user && user_count == 0

        # Verifies that the default username in config is valid
        if Config.current.disable_login
          username = Config.current.default_username
          unless username_exists username
            raise "Default username #{username} does not exist"
          end
        end
      end
      unless @auto_close
        @db = DB.open "sqlite3://#{@path}"
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

  private def get_db(&block : DB::Database ->)
    if @db.nil?
      DB.open "sqlite3://#{@path}" do |db|
        yield db
      end
    else
      yield @db.not_nil!
    end
  end

  def username_exists(username)
    exists = false
    MainFiber.run do
      get_db do |db|
        exists = db.query_one("select count(*) from users where " \
                              "username = (?)", username, as: Int32) > 0
      end
    end
    exists
  end

  def username_is_admin(username)
    is_admin = false
    MainFiber.run do
      get_db do |db|
        is_admin = db.query_one("select admin from users where " \
                                "username = (?)", username, as: Int32) > 0
      end
    end
    is_admin
  end

  def verify_user(username, password)
    out_token = nil
    MainFiber.run do
      get_db do |db|
        begin
          hash, token = db.query_one "select password, token from " \
                                     "users where username = (?)",
            username, as: {String, String?}
          unless verify_password hash, password
            Logger.debug "Password does not match the hash"
            next
          end
          Logger.debug "User #{username} verified"
          if token
            out_token = token
            next
          end
          token = random_str
          Logger.debug "Updating token for #{username}"
          db.exec "update users set token = (?) where username = (?)",
            token, username
          out_token = token
        rescue e
          Logger.error "Error when verifying user #{username}: #{e}"
        end
      end
    end
    out_token
  end

  def verify_token(token)
    username = nil
    MainFiber.run do
      get_db do |db|
        begin
          username = db.query_one "select username from users where " \
                                  "token = (?)", token, as: String
        rescue e
          Logger.debug "Unable to verify token"
        end
      end
    end
    username
  end

  def verify_admin(token)
    is_admin = false
    MainFiber.run do
      get_db do |db|
        begin
          is_admin = db.query_one "select admin from users where " \
                                  "token = (?)", token, as: Bool
        rescue e
          Logger.debug "Unable to verify user as admin"
        end
      end
    end
    is_admin
  end

  def list_users
    results = Array(Tuple(String, Bool)).new
    MainFiber.run do
      get_db do |db|
        db.query "select username, admin from users" do |rs|
          rs.each do
            results << {rs.read(String), rs.read(Bool)}
          end
        end
      end
    end
    results
  end

  def new_user(username, password, admin)
    validate_username username
    validate_password password
    admin = (admin ? 1 : 0)
    MainFiber.run do
      get_db do |db|
        hash = hash_password password
        db.exec "insert into users values (?, ?, ?, ?)",
          username, hash, nil, admin
      end
    end
  end

  def update_user(original_username, username, password, admin)
    admin = (admin ? 1 : 0)
    validate_username username
    validate_password password unless password.empty?
    MainFiber.run do
      get_db do |db|
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
  end

  def delete_user(username)
    MainFiber.run do
      get_db do |db|
        db.exec "delete from users where username = (?)", username
      end
    end
  end

  def logout(token)
    MainFiber.run do
      get_db do |db|
        begin
          db.exec "update users set token = (?) where token = (?)", nil, token
        rescue
        end
      end
    end
  end

  def get_id(path, is_title)
    id = nil
    MainFiber.run do
      get_db do |db|
        if is_title
          id = db.query_one? "select id from titles where path = (?)", path,
            as: String
        else
          id = db.query_one? "select id from ids where path = (?)", path,
            as: String
        end
      end
    end
    id
  end

  def insert_id(tp : IDTuple)
    @@insert_ids << tp
  end

  def bulk_insert_ids
    MainFiber.run do
      get_db do |db|
        db.transaction do |tran|
          conn = tran.connection
          @@insert_ids.each do |tp|
            if tp[:is_title]
              conn.exec "insert into titles values (?, ?, null)", tp[:id],
                tp[:path]
            else
              conn.exec "insert into ids values (?, ?)", tp[:path], tp[:id]
            end
          end
        end
      end
      @@insert_ids.clear
    end
  end

  def save_thumbnail(id : String, img : Image)
    MainFiber.run do
      get_db do |db|
        db.exec "insert into thumbnails values (?, ?, ?, ?, ?)", id, img.data,
          img.filename, img.mime, img.size
      end
    end
  end

  def get_thumbnail(id : String) : Image?
    img = nil
    MainFiber.run do
      get_db do |db|
        db.query_one? "select * from thumbnails where id = (?)", id do |res|
          img = Image.from_db res
        end
      end
    end
    img
  end

  def get_title_tags(id : String) : Array(String)
    tags = [] of String
    MainFiber.run do
      get_db do |db|
        db.query "select tag from tags where id = (?) order by tag", id do |rs|
          rs.each do
            tags << rs.read String
          end
        end
      end
    end
    tags
  end

  def get_tag_titles(tag : String) : Array(String)
    tids = [] of String
    MainFiber.run do
      get_db do |db|
        db.query "select id from tags where tag = (?)", tag do |rs|
          rs.each do
            tids << rs.read String
          end
        end
      end
    end
    tids
  end

  def list_tags : Array(String)
    tags = [] of String
    MainFiber.run do
      get_db do |db|
        db.query "select distinct tag from tags" do |rs|
          rs.each do
            tags << rs.read String
          end
        end
      end
    end
    tags
  end

  def add_tag(id : String, tag : String)
    err = nil
    MainFiber.run do
      begin
        get_db do |db|
          db.exec "insert into tags values (?, ?)", id, tag
        end
      rescue e
        err = e
      end
    end
    raise err.not_nil! if err
  end

  def delete_tag(id : String, tag : String)
    MainFiber.run do
      get_db do |db|
        db.exec "delete from tags where id = (?) and tag = (?)", id, tag
      end
    end
  end

  def optimize
    MainFiber.run do
      Logger.info "Starting DB optimization"
      get_db do |db|
        trash_ids = [] of String
        db.query "select path, id from ids" do |rs|
          rs.each do
            path = rs.read String
            trash_ids << rs.read String unless File.exists? path
          end
        end

        # Delete dangling IDs
        db.exec "delete from ids where id in " \
                "(#{trash_ids.map { |i| "'#{i}'" }.join ","})"
        Logger.debug "#{trash_ids.size} dangling IDs deleted" \
           if trash_ids.size > 0

        # Delete dangling thumbnails
        trash_thumbnails_count = db.query_one "select count(*) from " \
                                              "thumbnails where id not in " \
                                              "(select id from ids)", as: Int32
        if trash_thumbnails_count > 0
          db.exec "delete from thumbnails where id not in (select id from ids)"
          Logger.info "#{trash_thumbnails_count} dangling thumbnails deleted"
        end

        # Delete dangling tags
        trash_tags_count = db.query_one "select count(*) from tags " \
                                        "where id not in " \
                                        "(select id from ids)", as: Int32
        if trash_tags_count > 0
          db.exec "delete from tags where id not in (select id from ids)"
          Logger.info "#{trash_tags_count} dangling tags deleted"
        end
      end
      Logger.info "DB optimization finished"
    end
  end

  def close
    MainFiber.run do
      unless @db.nil?
        @db.not_nil!.close
      end
    end
  end

  def to_json(json : JSON::Builder)
    json.string self
  end
end
