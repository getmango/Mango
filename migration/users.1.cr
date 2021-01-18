class CreateUsers < MG::Base
  def up : String
    <<-SQL
    CREATE TABLE IF NOT EXISTS users (
      username TEXT NOT NULL,
      password TEXT NOT NULL,
      token TEXT,
      admin INTEGER NOT NULL
    );
    CREATE UNIQUE INDEX IF NOT EXISTS username_idx ON users (username);
    CREATE UNIQUE INDEX IF NOT EXISTS token_idx ON users (token);
    SQL
  end

  def down : String
    <<-SQL
    DROP TABLE users;
    SQL
  end
end
