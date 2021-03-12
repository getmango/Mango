private macro properties_to_hash(names)
  {
    {% for name in names %}
      "{{name.id}}" => {{name.id}}.to_s,
    {% end %}
  }
end

# Monkey-patch the structures in the `mangadex` shard to suit our needs
module MangaDex
  struct Client
    @@group_cache = {} of String => Group

    def self.from_config : Client
      self.new base_url: Config.current.mangadex["base_url"].to_s,
        api_url: Config.current.mangadex["api_url"].to_s
    end
  end

  struct Manga
    def rename(rule : Rename::Rule)
      rule.render properties_to_hash %w(id title author artist)
    end

    def to_info_json
      hash = JSON.parse(to_json).as_h
      _chapters = chapters.map do |c|
        JSON.parse c.to_info_json
      end
      hash["chapters"] = JSON::Any.new _chapters
      hash.to_json
    end
  end

  struct Chapter
    def rename(rule : Rename::Rule)
      hash = properties_to_hash %w(id title volume chapter lang_code language)
      hash["groups"] = groups.join(",", &.name)
      rule.render hash
    end

    def full_title
      rule = Rename::Rule.new \
        Config.current.mangadex["chapter_rename_rule"].to_s
      rename rule
    end

    def to_info_json
      hash = JSON.parse(to_json).as_h
      hash["language"] = JSON::Any.new language
      _groups = {} of String => JSON::Any
      groups.each do |g|
        _groups[g.name] = JSON::Any.new g.id
      end
      hash["groups"] = JSON::Any.new _groups
      hash["full_title"] = JSON::Any.new full_title
      hash.to_json
    end
  end
end
