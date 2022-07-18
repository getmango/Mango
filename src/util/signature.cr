require "./util"

class File
  abstract struct Info
    def inode : UInt64
      @stat.st_ino.to_u64
    end
  end

  # Returns the signature of the file at filename.
  # When it is not a supported file, returns 0. Otherwise, uses the inode
  #   number as its signature. On most file systems, the inode number is
  #   preserved even when the file is renamed, moved or edited.
  # Some cases that would cause the inode number to change:
  #   - Reboot/remount on some file systems
  #   - Replaced with a copied file
  #   - Moved to a different device
  # Since we are also using the relative paths to match ids, we won't lose
  #   information as long as the above changes do not happen together with
  #   a file/folder rename, with no library scan in between.
  def self.signature(filename) : UInt64
    if ArchiveEntry.is_valid?(filename) || is_supported_image_file(filename)
      File.info(filename).inode
    else
      0u64
    end
  end
end

class Dir
  # Returns the signature of the directory at dirname. See the comments for
  #   `File.signature` for more information.
  def self.signature(dirname) : UInt64
    signatures = [File.info(dirname).inode]
    self.open dirname do |dir|
      dir.entries.each do |fn|
        next if fn.starts_with? "."
        path = File.join dirname, fn
        if File.directory? path
          signatures << Dir.signature path
        else
          _sig = File.signature path
          # Only add its signature value to `signatures` when it is a
          #   supported file
          signatures << _sig if _sig > 0
        end
      end
    end
    Digest::CRC32.checksum(signatures.sort.join).to_u64
  end

  # Returns the contents signature of the directory at dirname for checking
  #   to rescan.
  # Rescan conditions:
  #   - When a file added, moved, removed, renamed (including which in nested
  #       directories)
  def self.contents_signature(dirname, cache = {} of String => String) : String
    return cache[dirname] if cache[dirname]?
    Fiber.yield
    signatures = [] of String
    self.open dirname do |dir|
      dir.entries.sort.each do |fn|
        next if fn.starts_with? "."
        path = File.join dirname, fn
        if File.directory? path
          signatures << Dir.contents_signature path, cache
        else
          # Only add its signature value to `signatures` when it is a
          #   supported file
          if ArchiveEntry.is_valid?(fn) || is_supported_image_file(fn)
            signatures << fn
          end
        end
        Fiber.yield
      end
    end
    hash = Digest::SHA1.hexdigest(signatures.join)
    cache[dirname] = hash
    hash
  end

  def self.directory_entry_signature(dirname, cache = {} of String => String)
    return cache[dirname + "?entry"] if cache[dirname + "?entry"]?
    Fiber.yield
    signatures = [] of String
    image_files = DirEntry.sorted_image_files dirname
    if image_files.size > 0
      image_files.each do |path|
        signatures << File.signature(path).to_s
      end
    end
    hash = Digest::SHA1.hexdigest(signatures.join)
    cache[dirname + "?entry"] = hash
    hash
  end
end
