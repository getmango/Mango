require "./spec_helper"

describe Plugin do
  describe "helper functions" do
    it "mango.text" do
      with_plugin do |plugin|
        res = plugin.eval <<-JS
        mango.text('<a href="https://github.com">Click Me<a>');
      JS
        res.should eq "Click Me"
      end
    end

    it "mango.text returns empty string when no text" do
      with_plugin do |plugin|
        res = plugin.eval <<-JS
        mango.text('<img src="https://github.com" />');
        JS
        res.should eq ""
      end
    end

    it "mango.css" do
      with_plugin do |plugin|
        res = plugin.eval <<-JS
        mango.css('<ul><li class="test">A</li><li class="test">B</li><li>C</li></ul>', 'li.test');

        JS
        res.should eq ["<li class=\"test\">A</li>", "<li class=\"test\">B</li>"]
      end
    end

    it "mango.css returns empty array when no match" do
      with_plugin do |plugin|
        res = plugin.eval <<-JS
        mango.css('<ul><li class="test">A</li><li class="test">B</li><li>C</li></ul>', 'li.noclass');
        JS
        res.should eq [] of String
      end
    end

    it "mango.attribute" do
      with_plugin do |plugin|
        res = plugin.eval <<-JS
        mango.attribute('<a href="https://github.com">Click Me<a>', 'href');
        JS
        res.should eq "https://github.com"
      end
    end

    it "mango.attribute returns undefined when no match" do
      with_plugin do |plugin|
        res = plugin.eval <<-JS
        mango.attribute('<div />', 'href') === undefined;
        JS
        res.should be_true
      end
    end

    # https://github.com/hkalexling/Mango/issues/320
    it "mango.attribute handles tags in attribute values" do
      with_plugin do |plugin|
        res = plugin.eval <<-JS
        mango.attribute('<div data-a="<img />" data-b="test" />', 'data-b');
        JS
        res.should eq "test"
      end
    end
  end
end
