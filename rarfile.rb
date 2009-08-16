# TODO: describe rar-files. look through after code that needs commenting
class RarFile
  BASIC_FIELDS = [:crc, :type, :flags, :header_size]
  FILE_FIELDS = [:unpacked_size, :os, :file_crc, :file_time, :rar_version, :pack_method, :name_length, :file_attrs]
  
  BLOCK_TYPES = [:marker, :archive, :file, :comment, :extra, :sub, :recovery, :sign, :new_sub, :eof]
  OSES = [:msdos, :os2, :win32, :unix, :mac, :beos]
  
  # if(Pattern.matches(".+\\.[P|p]art\\d+\\.rar", filename))
  # else if(Pattern.matches(".+\\.r((ar)|(\\d\\d)){1}", filename))
  # else if(Pattern.matches(".+\\.\\d\\d\\d", filename))
  
  # Matches ".part5.rar", ".rar", ".r00", ".Part5.rar"
  FILE_PATTERN = /\.(part\d+\.rar|r(\d+|ar))$/i
  
  # Will return nil unless index_files has been called first
  attr_reader :files
  
  # Just like with File.open can be called with a block, after which
  # the file will be closed.
  def initialize(filename)
    @fh = File.open(filename, 'rb')
    @files = nil
    @is_volume = nil
    @is_first_volume = nil
    @uses_new_numbering = nil
    @more_volumes = nil
    parse_header # skip marker block
    
    if block_given?
      yield self
      @fh.close
    end
  end
  
  # Just an alias of new-method. Imitates File.open
  def self.open(*args, &block)
    new(*args, &block)
  end
  
  def index_files
    @fh.seek(7, IO::SEEK_SET)
    parse_header # skip archive block
    @files = []
      
    begin
      loop do
        block = parse_header(true)
        @fh.seek(block[:data_size], IO::SEEK_CUR) if block[:data_size] # skip block contents
        @files << block if block[:type] == :file
      end
    rescue EOFError
      self.class.open(next_filename) { |next_vol| @files.concat(next_vol.index_files) } if @more_volumes
    end
    
    @files
  end
  
  private
  
    # TODO: not done!
    def next_filename
      name = @fh.path
      if name[-2..-1] == "ar"
        name[0..-3] + "00"
      else
        name[0..-3] + ("%02d" % (name[-2..-1].to_i + 1))
      end
      #       p = /\.(part(\d+)\.rar|r(\d+|ar))$/i
      #       name.gsub(p) { |vol_num| (vol_num == "ar") ? "00" : "%02d" % (vol_num.to_i + 1) }
    end
  
    def parse_header(return_block = false)
      block = {}
      parse_basic_header(block)
      
      case block[:type]
      when :marker
        # raise StandardError, 'Not a valid rar file' # TODO!
      when :archive
        @is_volume = block[:flags] & 0x1 != 0
        @is_first_volume = block[:flags] & 0x100 != 0
        @uses_new_numbering = block[:flags] & 0x10 != 0
      when :file
        return_block = true
        parse_file_header(block)
      when :eof
        @more_volumes = block[:flags] & 0x01 != 0
        raise EOFError
      else
        raise NotImplementedError, 'Unsupported block type' unless block[:skip_if_unknown]
      end
      
      @fh.seek(block[:header_ending], IO::SEEK_SET)
      block if return_block
    end
    
    def parse_basic_header(block)
      block[:header_start] = @fh.tell
      self.class.assign_block_fields(@fh.read(7).unpack("vCvv"), block, BASIC_FIELDS)
      block[:data_size] = @fh.read(4).unpack("V")[0] if block[:flags] & 0x8000 != 0
      block[:type] = BLOCK_TYPES[block[:type] - 0x72]
      block[:skip_if_unknown] = block[:flags] & 0x4000 != 0
      block[:header_ending] = block[:header_start] + block[:header_size]
    end
    
    def parse_file_header(block)
      self.class.assign_block_fields(@fh.read(21).unpack("VCVVCCvV"), block, FILE_FIELDS)
      if block[:flags] & 0x100 != 0
        block[:data_size] += @fh.read(4).unpack("V")[0] << 32
        block[:unpacked_size] += @fh.read(4).unpack("V")[0] << 32
      end
      block[:file_name] = @fh.read(block[:name_length]).unpack("a*")[0]
      block[:continued] = block[:flags] & 0x1 != 0
      block[:continues] = block[:flags] & 0x2 != 0
      block[:is_dir] = block[:flags] & 0xe0 == 0 # TODO: unsure about this
      block[:pack_method] -= 0x30 # becomes 0..5
      raise NotImplementedError, 'Unsupported pack method' if block[:pack_method] != 0 # no encrypytion/compression
      block[:os] = OSES[block[:os]]
      block[:file_time] = self.class.convert_msdos_time(block[:file_time])
    end
    
    # mapping-var is a mapping between indexes in fields and hashkeys in block
    def self.assign_block_fields(fields, block, mapping)
      fields.each_with_index { |value, index| block[mapping[index]] = value }
    end
    
    # 16 + 16 bits time and date, bit-indexed. Add 1980 to year, multiply seconds by two.
    def self.convert_msdos_time(time)
      year  = (time >> 25) + 1980
      month = (time >> 21) & 0x0f
      day   = (time >> 16) & 0x1f
      hour  = (time >> 11) & 0x1f
      min   = (time >> 5) & 0x3f
      sec   = (time & 0x1f) * 2
      Time.mktime(year, month, day, hour, min, sec)
    end
end

if $0 == __FILE__
  RarFile.open(ARGV.pop) do |rar|
    rar.index_files
    p rar.files
  end
end