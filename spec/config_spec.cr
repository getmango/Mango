require "./spec_helper"

describe Config do
  it "creates default config if it does not exist" do
    with_default_config do |config, path|
      File.exists?(path).should be_true
      config.port.should eq 9000
    end
  end

  it "correctly loads config" do
    config = Config.load "spec/asset/test-config.yml"
    config.port.should eq 3000
    config.base_url.should eq "/"
  end

  it "correctly reads config defaults from ENV" do
    ENV["LOG_LEVEL"] = "debug"
    config = Config.load "spec/asset/test-config.yml"
    config.log_level.should eq "debug"
    config.base_url.should eq "/"
  end

  it "correctly handles ENV truthiness" do
    ENV["CACHE_ENABLED"] = "false"
    config = Config.load "spec/asset/test-config.yml"
    config.cache_enabled.should be_false
    config.cache_log_enabled.should be_true
    config.disable_login.should be_false
  end
end
