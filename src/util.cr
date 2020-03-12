IMGS_PER_PAGE = 5

macro layout(name)
	render "src/views/#{{{name}}}.ecr", "src/views/layout.ecr"
end

macro send_img(env, img)
	send_file {{env}}, {{img}}.data, {{img}}.mime
end

macro get_username(env)
	# if the request gets here, its has gone through the auth handler, and
	# 	we can be sure that a valid token exists, so we can use not_nil! here
	cookie = {{env}}.request.cookies.find { |c| c.name == "token" }.not_nil!
	(@context.storage.verify_token cookie.value).not_nil!
end

macro send_json(env, json)
	{{env}}.response.content_type = "application/json"
	{{json}}
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
	return false
end

def is_numeric(str)
	/^\d+/.match(str) != nil
end

def split_by_alphanumeric(str)
	arr = [] of String
	str.scan(/([^\d\n\r]*)(\d*)([^\d\n\r]*)/) do |match|
		arr += match.captures.select{|s| s != ""}
	end
	arr
end

def compare_alphanumerically(c, d)
	is_c_bigger = c.size <=> d.size
	begin
		c.zip(d) do |a, b|
			if is_numeric(a) && is_numeric(b)
				compare = a.to_i <=> b.to_i
				return compare if compare != 0
			else
				compare = a <=> b
				return compare if compare != 0
			end
		end
		is_c_bigger
	end
end
