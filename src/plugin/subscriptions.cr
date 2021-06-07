require "uuid"

enum FilterType
  String
  NumMin
  NumMax
  DateMin
  DateMax
  Array

  def self.from_string(str)
    case str
    when "string"
      String
    when "number-min"
      NumMin
    when "number-max"
      NumMax
    when "date-min"
      DateMin
    when "date-max"
      DateMax
    when "array"
      Array
    else
      raise "Unknown filter type with string #{str}"
    end
  end
end

struct Filter
  include JSON::Serializable

  property key : String
  property value : String | Int32 | Int64 | Float32 | Nil
  property type : FilterType

  def initialize(@key, @value, @type)
  end

  def self.from_json(str) : Filter
    json = JSON.parse str
    key = json["key"].as_s
    type = FilterType.from_string json["type"].as_s
    _value = json["value"]
    value = _value.as_s? || _value.as_i32? || _value.as_i64? ||
            _value.as_f32? || nil
    self.new key, value, type
  end
end

struct Subscription
  include JSON::Serializable

  property id : String
  property plugin_id : String
  property name : String
  property created_at : Int64
  property last_checked : Int64
  property filters = [] of Filter

  def initialize(@plugin_id, @name)
    @id = UUID.random.to_s
    @created_at = Time.utc.to_unix
    @last_checked = Time.utc.to_unix
  end
end

struct SubscriptionList
  @dir : String
  @path : String

  getter ary = [] of Subscription

  forward_missing_to @ary

  def initialize(@dir)
    @path = Path[@dir, "subscriptions.json"]
    if File.exists? @path
      @ary = Array(Subscription).from_json File.read @path
    end
  end

  def save
    File.write @path, @ary.to_json
  end
end
