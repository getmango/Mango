require "./util/*"

class Upload
  def initialize(@dir : String)
    unless Dir.exists? @dir
      Logger.info "The uploads directory #{@dir} does not exist. " \
                  "Attempting to create it"
      Dir.mkdir_p @dir
    end
  end

  # Writes IO to a file with random filename in the uploads directory and
  #	  returns the full path of created file
  # e.g., save("image", ".png", <io>)
  #	  ==> "~/mango/uploads/image/<random string>.png"
  def save(sub_dir : String, ext : String, io : IO)
    full_dir = File.join @dir, sub_dir
    filename = random_str + ext
    file_path = File.join full_dir, filename

    unless Dir.exists? full_dir
      Logger.debug "creating directory #{full_dir}"
      Dir.mkdir_p full_dir
    end

    File.open file_path, "w" do |f|
      IO.copy io, f
    end

    file_path
  end

  # Converts path to a file in the uploads directory to the URL path for
  #   accessing the file.
  def path_to_url(path : String)
    dir_mathed = false
    ary = [] of String
    # We fill it with parts until it equals to @upload_dir
    dir_ary = [] of String

    Path.new(path).each_part do |part|
      if dir_mathed
        ary << part
      else
        dir_ary << part
        if File.same? @dir, File.join dir_ary
          dir_mathed = true
        end
      end
    end

    if ary.empty?
      Logger.warn "File #{path} is not in the upload directory #{@dir}"
      return
    end

    ary.unshift UPLOAD_URL_PREFIX
    File.join(ary).to_s
  end
end
