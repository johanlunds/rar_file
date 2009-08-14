class RarFile
  
  MARKER_BLOCK = 0x72
  ARCHIVE_BLOCK = 0x73
  FILE_BLOCK = 0x74
  
  STORE_METHOD = 0x30 # no compression or encryption
  
  OSES = [:msdos, :os2, :win32, :unix, :mac, :beos]
  
  BASIC_FIELDS = [:crc, :type, :flags, :header_size]
  FILE_FIELDS = [
    :packed_size, :unpacked_size, :os, :file_crc, :file_time, :rar_version, 
    :pack_method, :name_length, :file_attrs, :extra_packed_size, :extra_unpacked_size
  ]
  
  def initialize(filename)
    @fh = File.open(filename, 'rb')
    p parse_header(true) # marker block
    p parse_header(true) # archive block
    p parse_header(true) # first file
    
    if block_given?
      yield self
      @fh.close
    end
  end
  
  def self.open(*args, &block)
    new(*args, &block)
  end
  
  private
  
    def parse_header(want_return = false)
      block = {}
      block[:block_start] = @fh.tell
      basic_header = assign_block_fields(@fh.read(7).unpack("vCvv"), block, BASIC_FIELDS)
      
      case block[:type]
      when MARKER_BLOCK
        raise 'not a rar file' if basic_header != [24914, 114, 6689, 7]
      when ARCHIVE_BLOCK
        # do nothing
      when FILE_BLOCK
        want_return = true
        parse_file_header(block)
      else
        raise 'unsupported block type'
      end
      
      block[:header_ending] = block[:block_start] + block[:header_size]
      @fh.seek(block[:header_ending], IO::SEEK_SET)
      
      block if want_return
    end
    
    def parse_file_header(block)
      assign_block_fields(@fh.read(33).unpack("VVCVVCCvVVV"), block, FILE_FIELDS)
      
      if block[:flags] & 0x100 != 0
        block[:packed_size] += block[:extra_packed_size] << 32
        block[:unpacked_size] += block[:extra_unpacked_size] << 32
      else
        @fh.seek(-8, IO::SEEK_CUR)
      end
      
      block[:file_name] = @fh.read(block[:name_length]).unpack("a*")[0]
      raise 'unsupported pack method' if block[:pack_method] != STORE_METHOD
      block[:os] = OSES[block[:os]]
    end
    
    def assign_block_fields(fields, block, mapping)
      fields.each_with_index { |value, index| block[mapping[index]] = value }
    end
end

if $0 == __FILE__
  RarFile.open(ARGV.pop) do |f|
    puts f.inspect
  end
end