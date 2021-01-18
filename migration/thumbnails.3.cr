class CreateThumbnails < MG::Base
  def up : String
    <<-SQL
    CREATE TABLE IF NOT EXISTS thumbnails (
      id TEXT NOT NULL,
      data BLOB NOT NULL,
      filename TEXT NOT NULL,
      mime TEXT NOT NULL,
      size INTEGER NOT NULL
    );
    CREATE UNIQUE INDEX IF NOT EXISTS tn_index ON thumbnails (id);
    SQL
  end

  def down : String
    <<-SQL
    DROP TABLE thumbnails;
    SQL
  end
end
