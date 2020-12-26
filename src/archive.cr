require "compress/zip"
require "archive"

# A unified class to handle all supported archive formats. It uses the
#   Compress::Zip module in crystal standard library if the target file is
#   a zip archive. Otherwise it uses `archive.cr`.
class ArchiveFile
  def initialize(@filename : String)
    if [".cbz", ".zip"].includes? File.extname filename
      @archive_file = Compress::Zip::File.new filename
    else
      @archive_file = Archive::File.new filename
    end
  end

  def self.open(filename : String, &)
    s = self.new filename
    yield s
    s.close
  end

  def close
    if @archive_file.is_a? Compress::Zip::File
      @archive_file.as(Compress::Zip::File).close
    end
  end

  # Lists all file entries
  def entries
    ary = [] of Compress::Zip::File::Entry | Archive::Entry
    @archive_file.entries.map do |e|
      if (e.is_a? Compress::Zip::File::Entry && e.file?) ||
         (e.is_a? Archive::Entry && e.info.file?)
        ary.push e
      end
    end
    ary
  end

  def read_entry(e : Compress::Zip::File::Entry | Archive::Entry) : Bytes?
    if e.is_a? Compress::Zip::File::Entry
      data = nil
      e.open do |io|
        slice = Bytes.new e.uncompressed_size
        bytes_read = io.read_fully? slice
        data = slice if bytes_read
      end
      data
    else
      e.read
    end
  end

  def check
    if @archive_file.is_a? Archive::File
      @archive_file.as(Archive::File).check
    end
  end
end
