class RelativePath < MG::Base
  def up : String
    base = Config.current.library_path
    base = base[...-1] if base.ends_with? "/"

    <<-SQL
    -- update the path column in ids to relative paths
    UPDATE ids
    SET path = REPLACE(path, '#{base}', '');

    -- update the path column in titles to relative paths
    UPDATE titles
    SET path = REPLACE(path, '#{base}', '');
    SQL
  end

  def down : String
    base = Config.current.library_path
    base = base[...-1] if base.ends_with? "/"

    <<-SQL
    -- update the path column in ids to absolute paths
    UPDATE ids
    SET path = '#{base}' || path;

    -- update the path column in titles to absolute paths
    UPDATE titles
    SET path = '#{base}' || path;
    SQL
  end
end
