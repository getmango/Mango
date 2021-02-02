class IDSignature < MG::Base
  def up : String
    <<-SQL
    ALTER TABLE ids ADD COLUMN signature TEXT;
    SQL
  end

  def down : String
    <<-SQL
    -- remove signature column from ids
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
    SQL
  end
end
