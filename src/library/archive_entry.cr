require "yaml"

require "./entry"

class ArchiveEntry < Entry
  include YAML::Serializable

  getter zip_path : String

  def initialize(@zip_path, @book)
    storage = Storage.default
    @path = @zip_path
    @encoded_path = URI.encode @zip_path
    @title = File.basename @zip_path, File.extname @zip_path
    @encoded_title = URI.encode @title
    @size = (File.size @zip_path).humanize_bytes
    id = storage.get_entry_id @zip_path, File.signature(@zip_path)
    if id.nil?
      id = random_str
      storage.insert_entry_id({
        path:      @zip_path,
        id:        id,
        signature: File.signature(@zip_path).to_s,
      })
    end
    @id = id
    @mtime = File.info(@zip_path).modification_time

    unless File.readable? @zip_path
      @err_msg = "File #{@zip_path} is not readable."
      Logger.warn "#{@err_msg} Please make sure the " \
                  "file permission is configured correctly."
      return
    end

    archive_exception = validate_archive @zip_path
    unless archive_exception.nil?
      @err_msg = "Archive error: #{archive_exception}"
      Logger.warn "Unable to extract archive #{@zip_path}. " \
                  "Ignoring it. #{@err_msg}"
      return
    end

    file = ArchiveFile.new @zip_path
    @pages = file.entries.count do |e|
      SUPPORTED_IMG_TYPES.includes? \
        MIME.from_filename? e.filename
    end
    file.close
  end

  private def sorted_archive_entries
    ArchiveFile.open @zip_path do |file|
      entries = file.entries
        .select { |e|
          SUPPORTED_IMG_TYPES.includes? \
            MIME.from_filename? e.filename
        }
        .sort! { |a, b|
          compare_numerically a.filename, b.filename
        }
      yield file, entries
    end
  end

  def read_page(page_num)
    raise "Unreadble archive. #{@err_msg}" if @err_msg
    img = nil
    begin
      sorted_archive_entries do |file, entries|
        page = entries[page_num - 1]
        data = file.read_entry page
        if data
          img = Image.new data, MIME.from_filename(page.filename),
            page.filename, data.size
        end
      end
    rescue e
      Logger.warn "Unable to read page #{page_num} of #{@zip_path}. Error: #{e}"
    end
    img
  end

  def page_dimensions
    sizes = [] of Hash(String, Int32)
    sorted_archive_entries do |file, entries|
      entries.each_with_index do |e, i|
        begin
          data = file.read_entry(e).not_nil!
          size = ImageSize.get data
          sizes << {
            "width"  => size.width,
            "height" => size.height,
          }
        rescue e
          Logger.warn "Failed to read page #{i} of entry #{zip_path}. #{e}"
          sizes << {"width" => 1000_i32, "height" => 1000_i32}
        end
      end
    end
    sizes
  end

  def examine : Bool
    File.exists? @zip_path
  end

  def self.is_valid?(path : String) : Bool
    is_supported_file path
  end
end
