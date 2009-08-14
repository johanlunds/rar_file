class RarFile
  BLOCK_TYPES = [:marker, :archive, :file]
  OSES = [:msdos, :os2, :win32, :unix, :mac, :beos]
  
  BASIC_FIELDS = [:crc, :type, :flags, :header_size]
  FILE_FIELDS = [
    :unpacked_size, :os, :file_crc, :file_time, :rar_version, :pack_method,
    :name_length, :file_attrs
  ]
  
  def initialize(filename)
    @fh = File.open(filename, 'rb')
    @files = nil
    p parse_header(true) # skip marker block
    
    if block_given?
      yield self
      @fh.close
    end
  end
  
  def self.open(*args, &block)
    new(*args, &block)
  end
  
  def list_contents
    @fh.seek(7, IO::SEEK_SET)
    p parse_header(true) # skip archive block
    @files = []
      
    begin
      loop do
        block = parse_header(true)
        @fh.seek(block[:data_size], IO::SEEK_CUR) if block[:data_size] # skip file data
        # @files << block if block[:type] == :file
        p block
      end
    rescue EOFError
    end
    
    @files
  end
  
  private
  
    def parse_header(want_return = false)
      block = {}
      parse_basic_header(block)
      
      case block[:type]
      when :marker
        p BASIC_FIELDS.map { |v| block[v] }
        raise 'not a rar file' if BASIC_FIELDS.map { |v| block[v] } != [24914, 114, 6689, 7]
      when :archive
        # do nothing
      when :file
        want_return = true
        parse_file_header(block)
      else
        raise 'unsupported block type' unless block[:skip_if_unknown]
      end
      
      block[:header_ending] = block[:header_start] + block[:header_size]
      @fh.seek(block[:header_ending], IO::SEEK_SET)
      
      block if want_return
    end
    
    def parse_basic_header(block)
      block[:header_start] = @fh.tell
      assign_block_fields(@fh.read(7).unpack("vCvv"), block, BASIC_FIELDS)
      
      if block[:flags] & 0x8000 != 0
        block[:data_size] = @fh.read(4).unpack("V")[0]
      end
      
      block[:type] = BLOCK_TYPES[block[:type] - 0x72]
      block[:skip_if_unknown] = block[:flags] & 0x4000 != 0
    end
    
    def parse_file_header(block)
      assign_block_fields(@fh.read(21).unpack("VCVVCCvV"), block, FILE_FIELDS)
      
      if block[:flags] & 0x100 != 0
        extra_data_size, extra_unpacked_size = @fh.read(8).unpack("VV")
        block[:data_size] += extra_data_size << 32
        block[:unpacked_size] += extra_unpacked_size << 32
      end
      
      block[:file_name] = @fh.read(block[:name_length]).unpack("a*")[0]
      block[:pack_method] -= 0x30 # becomes 1..5
      raise 'unsupported pack method' if block[:pack_method] != 0 # no encrypytion/compression
      block[:os] = OSES[block[:os]]
    end
    
    def assign_block_fields(fields, block, mapping)
      fields.each_with_index { |value, index| block[mapping[index]] = value }
    end
end

if $0 == __FILE__
  RarFile.open(ARGV.pop) do |f|
    puts f.list_contents
  end
end