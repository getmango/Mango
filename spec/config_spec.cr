require "./spec_helper"

describe Config do
  it "creates config if it does not exist" do
    with_default_config do |config, logger, path|
      File.exists?(path).should be_true
    end
  end

  it "correctly loads config" do
    config = Config.load "spec/asset/test-config.yml"
    config.port.should eq 3000
  end
end
