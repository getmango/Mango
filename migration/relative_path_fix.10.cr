# In DB version 8, we replaced the absolute paths in DB with relative paths,
#   but we mistakenly left the starting slashes. This migration removes them.
class RelativePathFix < MG::Base
  def up : String
    <<-SQL
    -- remove leading slashes from the paths in ids
    UPDATE ids
    SET path = SUBSTR(path, 2, LENGTH(path) - 1)
    WHERE path LIKE '/%';

    -- remove leading slashes from the paths in titles
    UPDATE titles
    SET path = SUBSTR(path, 2, LENGTH(path) - 1)
    WHERE path LIKE '/%';
    SQL
  end

  def down : String
    <<-SQL
    -- add leading slashes to paths in ids
    UPDATE ids
    SET path = '/' || path
    WHERE path NOT LIKE '/%';

    -- add leading slashes to paths in titles
    UPDATE titles
    SET path = '/' || path
    WHERE path NOT LIKE '/%';
    SQL
  end
end
