require "spec"
require "../src/queue"
require "../src/server"
require "../src/config"
require "../src/main_fiber"
require "../src/plugin/plugin"

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
    file
  else
    File.new path
  end
end

def with_default_config
  temp_config = get_tempfile "mango-test-config"
  config = Config.load temp_config.path
  config.set_current
  yield config, temp_config.path
  temp_config.delete
end

def with_storage
  with_default_config do
    temp_db = get_tempfile "mango-test-db"
    storage = Storage.new temp_db.path, false
    clear = yield storage, temp_db.path
    if clear == true
      temp_db.delete
    end
  end
end

def with_plugin
  with_default_config do
    plugin = Plugin.new "test", "spec/asset/plugins"
    yield plugin
  end
end
