require "big"

IMGS_PER_PAGE     = 5
UPLOAD_URL_PREFIX = "/uploads"

macro layout(name)
  base_url = Config.current.base_url
  begin
    cookie = env.request.cookies.find { |c| c.name == "token" }
    is_admin = false
    unless cookie.nil?
      is_admin = @context.storage.verify_admin cookie.value
    end
    render "src/views/#{{{name}}}.ecr", "src/views/layout.ecr"
  rescue e
    message = e.to_s
    @context.error message
    render "src/views/message.ecr", "src/views/layout.ecr"
  end
end

macro send_img(env, img)
  send_file {{env}}, {{img}}.data, {{img}}.mime
end

macro get_username(env)
  # if the request gets here, it has gone through the auth handler, and
  #   we can be sure that a valid token exists, so we can use not_nil! here
  cookie = {{env}}.request.cookies.find { |c| c.name == "token" }.not_nil!
  (@context.storage.verify_token cookie.value).not_nil!
end

def send_json(env, json)
  env.response.content_type = "application/json"
  env.response.print json
end

def send_attachment(env, path)
  MIME.register ".cbz", "application/vnd.comicbook+zip"
  MIME.register ".cbr", "application/vnd.comicbook-rar"
  send_file env, path, filename: File.basename(path), disposition: "attachment"
end

def hash_to_query(hash)
  hash.map { |k, v| "#{k}=#{v}" }.join("&")
end

def request_path_startswith(env, ary)
  ary.each do |prefix|
    if env.request.path.starts_with? prefix
      return true
    end
  end
  false
end

def is_numeric(str)
  /^\d+/.match(str) != nil
end

def split_by_alphanumeric(str)
  arr = [] of String
  str.scan(/([^\d\n\r]*)(\d*)([^\d\n\r]*)/) do |match|
    arr += match.captures.select { |s| s != "" }
  end
  arr
end

def compare_alphanumerically(c, d)
  is_c_bigger = c.size <=> d.size
  if c.size > d.size
    d += [nil] * (c.size - d.size)
  elsif c.size < d.size
    c += [nil] * (d.size - c.size)
  end
  c.zip(d) do |a, b|
    return -1 if a.nil?
    return 1 if b.nil?
    if is_numeric(a) && is_numeric(b)
      compare = a.to_big_i <=> b.to_big_i
      return compare if compare != 0
    else
      compare = a <=> b
      return compare if compare != 0
    end
  end
  is_c_bigger
end

def compare_alphanumerically(a : String, b : String)
  compare_alphanumerically split_by_alphanumeric(a), split_by_alphanumeric(b)
end

def validate_archive(path : String) : Exception?
  file = ArchiveFile.new path
  file.check
  file.close
  return
rescue e
  e
end

def random_str
  UUID.random.to_s.gsub "-", ""
end

def redirect(env, path)
  base = Config.current.base_url
  env.redirect File.join base, path
end

def validate_username(username)
  if username.size < 3
    raise "Username should contain at least 3 characters"
  end
  if (username =~ /^[A-Za-z0-9_]+$/).nil?
    raise "Username should contain alphanumeric characters " \
          "and underscores only"
  end
end

def validate_password(password)
  if password.size < 6
    raise "Password should contain at least 6 characters"
  end
  if (password =~ /^[[:ascii:]]+$/).nil?
    raise "password should contain ASCII characters only"
  end
end
