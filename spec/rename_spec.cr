require "./spec_helper"
require "../src/rename"

include Rename

describe Rule do
  it "raises on nested brackets" do
    expect_raises Exception do
      Rule.new "[[]]"
    end
    expect_raises Exception do
      Rule.new "{{}}"
    end
  end

  it "raises on unclosed brackets" do
    expect_raises Exception do
      Rule.new "["
    end
    expect_raises Exception do
      Rule.new "{"
    end
    expect_raises Exception do
      Rule.new "[{]}"
    end
  end

  it "raises when closing unopened brackets" do
    expect_raises Exception do
      Rule.new "]"
    end
    expect_raises Exception do
      Rule.new "[}"
    end
  end

  it "handles `|` in patterns" do
    rule = Rule.new "{a|b|c}"
    rule.render({"b" => "b"}).should eq "b"
    rule.render({"a" => "a", "b" => "b"}).should eq "a"
  end

  it "raises on escaped characters" do
    expect_raises Exception do
      Rule.new "hello/world"
    end
  end

  it "handles spaces in patterns" do
    rule = Rule.new "{  a }"
    rule.render({"a" => "a"}).should eq "a"
  end

  it "strips leading and tailing spaces" do
    rule = Rule.new "  hello "
    rule.render({"a" => "a"}).should eq "hello"
  end

  it "renders a few examples correctly" do
    rule = Rule.new "[Ch. {chapter }] {title | id} testing"
    rule.render({"id" => "ID"}).should eq "ID testing"
    rule.render({"chapter" => "CH", "id" => "ID"})
      .should eq "Ch. CH ID testing"
    rule.render({} of String => String).should eq "testing"
  end

  it "escapes illegal characters" do
    rule = Rule.new "{a}"
    rule.render({"a" => "/?<>:*|\"^"}).should eq "_________"
  end

  it "strips trailing spaces and dots" do
    rule = Rule.new "hello. world. .."
    rule.render({} of String => String).should eq "hello. world"
  end
end
