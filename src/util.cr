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
