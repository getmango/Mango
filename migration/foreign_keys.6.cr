class ForeignKeys < MG::Base
  def up : String
    <<-SQL
    -- add foreign key to tags
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

    -- add foreign key to thumbnails
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
    SQL
  end

  def down : String
    <<-SQL
    -- remove foreign key from thumbnails
    ALTER TABLE thumbnails RENAME TO tmp;

    CREATE TABLE thumbnails (
      id TEXT NOT NULL,
      data BLOB NOT NULL,
      filename TEXT NOT NULL,
      mime TEXT NOT NULL,
      size INTEGER NOT NULL
    );

    INSERT INTO thumbnails
    SELECT * FROM tmp;

    DROP TABLE tmp;

    CREATE UNIQUE INDEX tn_index ON thumbnails (id);

    -- remove foreign key from tags
    ALTER TABLE tags RENAME TO tmp;

    CREATE TABLE tags (
      id TEXT NOT NULL,
      tag TEXT NOT NULL,
      UNIQUE (id, tag)
    );

    INSERT INTO tags
    SELECT * FROM tmp;

    DROP TABLE tmp;

    CREATE INDEX tags_id_idx ON tags (id);
    CREATE INDEX tags_tag_idx ON tags (tag);
    SQL
  end
end
