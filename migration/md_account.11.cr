class CreateMangaDexAccount < MG::Base
  def up : String
    <<-SQL
    CREATE TABLE md_account (
      username TEXT NOT NULL PRIMARY KEY,
      token TEXT NOT NULL,
      expire INTEGER NOT NULL,
      FOREIGN KEY (username) REFERENCES users (username)
        ON UPDATE CASCADE
        ON DELETE CASCADE
    );
    SQL
  end

  def down : String
    <<-SQL
    DROP TABLE md_account;
    SQL
  end
end
