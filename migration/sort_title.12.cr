class SortTitle < MG::Base
  def up : String
    <<-SQL
    -- add sort_title column to ids and titles
    ALTER TABLE ids ADD COLUMN sort_title TEXT;
    ALTER TABLE titles ADD COLUMN sort_title TEXT;
    SQL
  end

  def down : String
    <<-SQL
    -- remove sort_title column from ids
    ALTER TABLE ids RENAME TO tmp;

    CREATE TABLE ids (
      path TEXT NOT NULL,
      id TEXT NOT NULL,
      signature TEXT,
      unavailable INTEGER NOT NULL DEFAULT 0
    );

    INSERT INTO ids
    SELECT path, id, signature, unavailable
    FROM tmp;

    DROP TABLE tmp;

    -- recreate the indices
    CREATE UNIQUE INDEX path_idx ON ids (path);
    CREATE UNIQUE INDEX id_idx ON ids (id);

    -- recreate the foreign key constraint on thumbnails
    ALTER TABLE thumbnails RENAME TO tmp;

    CREATE TABLE thumbnails (
      id TEXT NOT NULL,
      data BLOB NOT NULL,
      filename TEXT NOT NULL,
      mime TEXT NOT NULL,
      size INTEGER NOT NULL,
      FOREIGN KEY (id) REFERENCES ids (id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
    );

    INSERT INTO thumbnails
    SELECT * FROM tmp;

    DROP TABLE tmp;

    CREATE UNIQUE INDEX tn_index ON thumbnails (id);

    -- remove sort_title column from titles
    ALTER TABLE titles RENAME TO tmp;

    CREATE TABLE titles (
      id TEXT NOT NULL,
      path TEXT NOT NULL,
      signature TEXT,
      unavailable INTEGER NOT NULL DEFAULT 0
    );

    INSERT INTO titles
    SELECT id, path, signature, unavailable
    FROM tmp;

    DROP TABLE tmp;

    -- recreate the indices
    CREATE UNIQUE INDEX titles_id_idx on titles (id);
    CREATE UNIQUE INDEX titles_path_idx on titles (path);

    -- recreate the foreign key constraint on tags
    ALTER TABLE tags RENAME TO tmp;

    CREATE TABLE tags (
      id TEXT NOT NULL,
      tag TEXT NOT NULL,
      UNIQUE (id, tag),
      FOREIGN KEY (id) REFERENCES titles (id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
    );

    INSERT INTO tags
    SELECT * FROM tmp;

    DROP TABLE tmp;

    CREATE INDEX tags_id_idx ON tags (id);
    CREATE INDEX tags_tag_idx ON tags (tag);
    SQL
  end
end
