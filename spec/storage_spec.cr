require "./spec_helper"

describe Storage do
	temp_config = File.tempfile "mango-test-config"
	temp_db = File.tempfile "mango-test-db"
	config = Config.load temp_config.path
	user_token = nil
	admin_token = nil

	it "creates DB at given path" do
		storage = Storage.new temp_db.path, MLogger.new config
		File.exists?(temp_db.path).should be_true
	end
	it "deletes user" do
		storage = Storage.new temp_db.path, MLogger.new config
		storage.delete_user "admin"
	end
	it "creates new user" do
		storage = Storage.new temp_db.path, MLogger.new config
		storage.new_user "user", "123456", false
		storage.new_user "admin", "123456", true
	end
	it "verifies username/password combination" do
		storage = Storage.new temp_db.path, MLogger.new config
		user_token = storage.verify_user "user", "123456"
		admin_token = storage.verify_user "admin", "123456"
		user_token.should_not be_nil
		admin_token.should_not be_nil
	end
	it "rejects duplicate username" do
		storage = Storage.new temp_db.path, MLogger.new config
		expect_raises SQLite3::Exception,
			"UNIQUE constraint failed: users.username" do
			storage.new_user "admin", "123456", true
		end
	end
	it "verifies token" do
		storage = Storage.new temp_db.path, MLogger.new config
		token = storage.verify_token user_token
		token.should eq "user"
	end
	it "verfies admin token" do
		storage = Storage.new temp_db.path, MLogger.new config
		storage.verify_admin(admin_token).should be_true
	end
	it "rejects non-admin token" do
		storage = Storage.new temp_db.path, MLogger.new config
		storage.verify_admin(user_token).should be_false
	end
	it "updates user" do
		storage = Storage.new temp_db.path, MLogger.new config
		storage.update_user "admin", "admin", "654321", true
		token = storage.verify_user "admin", "654321"
		token.should eq admin_token
	end
	it "logs user out" do
		storage = Storage.new temp_db.path, MLogger.new config
		storage.logout user_token
		storage.logout admin_token
		storage.verify_token(user_token).should be_nil
		storage.verify_token(admin_token).should be_nil
	end

	temp_config.delete
	temp_db.delete
end
