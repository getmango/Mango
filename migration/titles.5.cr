class CreateTitles < MG::Base
  def up : String
    <<-SQL
    -- create titles
    CREATE TABLE titles (
      id TEXT NOT NULL,
      path TEXT NOT NULL,
      signature TEXT
    );
    CREATE UNIQUE INDEX titles_id_idx on titles (id);
    CREATE UNIQUE INDEX titles_path_idx on titles (path);

    -- migrate data from ids to titles
    INSERT INTO titles
    SELECT id, path, null
    FROM ids
    WHERE is_title = 1;

    DELETE FROM ids
    WHERE is_title = 1;

    -- remove the is_title column from ids
    ALTER TABLE ids RENAME TO tmp;

    CREATE TABLE ids (
      path TEXT NOT NULL,
      id TEXT NOT NULL
    );

    INSERT INTO ids
    SELECT path, id
    FROM tmp;

    DROP TABLE tmp;

    -- recreate the indices
    CREATE UNIQUE INDEX path_idx ON ids (path);
    CREATE UNIQUE INDEX id_idx ON ids (id);
    SQL
  end

  def down : String
    <<-SQL
    -- insert the is_title column
    ALTER TABLE ids ADD COLUMN is_title INTEGER NOT NULL DEFAULT 0;

    -- migrate data from titles to ids
    INSERT INTO ids
    SELECT path, id, 1
    FROM titles;

    -- remove titles
    DROP TABLE titles;
    SQL
  end
end
