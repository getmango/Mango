require "big"

IMGS_PER_PAGE     = 5
UPLOAD_URL_PREFIX = "/uploads"

macro layout(name)
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

# When downloading from MangaDex, the zip/cbz file would not be valid
#   before the download is completed. If we scan the zip file,
#   Entry.new would throw, so we use this method to check before
#   constructing Entry
def validate_zip(path : String) : Exception?
  file = Zip::File.new path
  file.close
  return
rescue e
  e
end

def random_str
  UUID.random.to_s.gsub "-", ""
end
