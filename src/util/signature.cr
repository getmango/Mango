require "./util"

class File
  abstract struct Info
    def inode
      @stat.st_ino
    end
  end

  # Returns the signature of the file at filename.
  # When it is not a supported file, returns 0. Otherwise, calculate the
  #   signature by combining its inode value, file size and mtime. This
  #   ensures that moving (unless to another device) and renaming the file
  #   preserves the signature, while copying or editing the file changes it.
  def self.signature(filename) : UInt64
    return 0u64 unless is_interesting_file filename
    info = File.info filename
    signatures = [
      info.inode,
      File.size(filename),
      info.modification_time.to_unix,
    ]
    Digest::CRC32.checksum(signatures.sort.join).to_u64
  end
end

class Dir
  # Returns the signature of the directory at dirname.
  # The signature is calculated by combining its mtime and the signatures of
  #   all directories and files in it. This ensures that moving (unless to
  #   another device) and renaming the directory preserves the signature,
  #   while copying or editing its content changes it.
  def self.signature(dirname) : UInt64
    signatures = [] of (UInt64 | Int64)
    signatures << File.info(dirname).modification_time.to_unix
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
end
