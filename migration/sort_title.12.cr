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
    -- drop sort_title column to ids and titles
    ALTER TABLE ids DROP COLUMN sort_title;
    ALTER TABLE titles DROP COLUMN sort_title;
    SQL
  end
end
