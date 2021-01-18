class CreateTags < MG::Base
  def up : String
    <<-SQL
    CREATE TABLE IF NOT EXISTS tags (
      id TEXT NOT NULL,
      tag TEXT NOT NULL,
      UNIQUE (id, tag)
    );
    CREATE INDEX IF NOT EXISTS tags_id_idx ON tags (id);
    CREATE INDEX IF NOT EXISTS tags_tag_idx ON tags (tag);
    SQL
  end

  def down : String
    <<-SQL
    DROP TABLE tags;
    SQL
  end
end
