# TODO: describe rar-files. look through after code that needs commenting
class RarFile
  BASIC_FIELDS = [:crc, :type, :flags, :header_size]
  FILE_FIELDS = [:unpacked_size, :os, :file_crc, :file_time, :rar_version, :pack_method, :name_length, :file_attrs]
  
  BLOCK_TYPES = [:marker, :archive, :file, :comment, :extra, :sub, :recovery, :sign, :new_sub, :eof]
  OSES = [:msdos, :os2, :win32, :unix, :mac, :beos]
  
  def initialize(filename)
    @fh = File.open(filename, 'rb')
    @files = nil
    parse_header # skip marker block
    
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
    parse_header # skip archive block
    @files = []
      
    begin
      loop do
        block = parse_header(true)
        @fh.seek(block[:data_size], IO::SEEK_CUR) if block[:data_size] # skip block contents
        @files << block if block[:type] == :file
      end
    rescue EOFError
    end
    
    @files
  end
  
  private
  
    def parse_header(return_block = false)
      block = {}
      parse_basic_header(block)
      
      case block[:type]
      when :marker
        # raise StandardError, 'Not a valid rar file' # TODO!
      when :archive
        # do nothing
      when :file
        return_block = true
        parse_file_header(block)
      when :eof
        raise EOFError
      else
        raise NotImplementedError, 'Unsupported block type' unless block[:skip_if_unknown]
      end
      
      @fh.seek(block[:header_ending], IO::SEEK_SET)
      block if return_block
    end
    
    def parse_basic_header(block)
      block[:header_start] = @fh.tell
      assign_block_fields(@fh.read(7).unpack("vCvv"), block, BASIC_FIELDS)
      block[:data_size] = @fh.read(4).unpack("V")[0] if block[:flags] & 0x8000 != 0
      block[:type] = BLOCK_TYPES[block[:type] - 0x72]
      block[:skip_if_unknown] = block[:flags] & 0x4000 != 0
      block[:header_ending] = block[:header_start] + block[:header_size]
    end
    
    def parse_file_header(block)
      assign_block_fields(@fh.read(21).unpack("VCVVCCvV"), block, FILE_FIELDS)
      if block[:flags] & 0x100 != 0
        block[:data_size] += @fh.read(4).unpack("V")[0] << 32
        block[:unpacked_size] += @fh.read(4).unpack("V")[0] << 32
      end
      block[:file_name] = @fh.read(block[:name_length]).unpack("a*")[0]
      block[:pack_method] -= 0x30 # becomes 0..5
      raise NotImplementedError, 'Unsupported pack method' if block[:pack_method] != 0 # no encrypytion/compression
      block[:os] = OSES[block[:os]]
    end
    
    def assign_block_fields(fields, block, mapping)
      fields.each_with_index { |value, index| block[mapping[index]] = value }
    end
end

if $0 == __FILE__
  RarFile.open(ARGV.pop) do |f|
    p f.list_contents
  end
end