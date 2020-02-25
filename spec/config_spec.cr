require "./spec_helper"

describe Config do
	it "creates config if it does not exist" do
		tempfile = File.tempfile "mango-test-config"
		config = Config.load tempfile.path
		File.exists?(tempfile.path).should be_true
		tempfile.delete
	end
	it "correctly loads config" do
		config = Config.load "spec/asset/test-config.yml"
		config.port.should eq 3000
	end
end
