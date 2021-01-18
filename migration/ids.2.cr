class CreateIds < MG::Base
  def up : String
    <<-SQL
    CREATE TABLE IF NOT EXISTS ids (
      path TEXT NOT NULL,
      id TEXT NOT NULL,
      is_title INTEGER NOT NULL
    );
    CREATE UNIQUE INDEX IF NOT EXISTS path_idx ON ids (path);
    CREATE UNIQUE INDEX IF NOT EXISTS id_idx ON ids (id);
    SQL
  end

  def down : String
    <<-SQL
    DROP TABLE ids;
    SQL
  end
end
