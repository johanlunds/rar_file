# TODO:
# - describe rar-files. look through after code that needs commenting.
# - add rar files for testing (both normal and split). Use RAR command-line program
class RarFile
  BASIC_FIELDS = [:crc, :type, :flags, :header_size]
  FILE_FIELDS = [:unpacked_size, :os, :file_crc, :file_time, :rar_version, :pack_method, :name_length, :file_attrs]
  
  BLOCK_TYPES = [:marker, :archive, :file, :comment, :extra, :sub, :recovery, :sign, :new_sub, :eof]
  OSES = [:msdos, :os2, :win32, :unix, :mac, :beos]
  
  class RarFileError < IOError
  end
  
  class NotARarFile < RarFileError
  end
  
  # Just like with File.open can be called with a block, after which the file 
  # will be closed. If the opened file isn't a valid rar file NotARarFile will be raised.
  def initialize(filename)
    raise NotARarFile, 'Not a valid rar file' unless self.class.is_rar_file?(filename)
    @fh = File.open(filename, 'rb')
    @file_blocks = nil
    @all_file_blocks = nil
    @is_volume = nil
    @is_first_volume = nil
    @more_volumes = nil
    @next_volume = nil
    
    if block_given?
      yield self
      close
    end
  end
  
  # Just an alias of new-method. Imitates File.open
  def self.open(*args, &block)
    new(*args, &block)
  end
  
  def close
    @next_volume.close if @next_volume
    @fh.close
  end
  
  # All rar files should begin with a fixed bit sequence. 0x21726152 is "Rar!" in ASCII
  def self.is_rar_file?(filename)
    File.open(filename, 'rb') { |fh| fh.read(7).unpack("vCvv") == [0x6152, 0x72, 0x1a21, 0x7] }
  end
  
  def filenames
    all_file_blocks.map { |block| block[:filename] }.uniq
  end
  
  def filesize(filename)
    block = all_file_blocks.find { |block| block[:filename] == filename }
    block[:unpacked_size]
  end
  
  def read(filename)
    # Note: doesn't use :continued_from_prev or :continues_in_next that every
    # file block has. Just assumes the array is sorted instead.
    blocks = all_file_blocks.find_all { |block| block[:filename] == filename }
    blocks.inject("") do |data, block|
      fh = block[:file_handle]
      fh.seek(block[:header_ending], IO::SEEK_SET)
      data << fh.read(block[:data_size])
    end
  end
  
  protected
  
    # Will memoize the result if self is first volume
    def all_file_blocks
      return @all_file_blocks if @all_file_blocks
      list_contents! unless @file_blocks # only list contents once
      
      result = if @next_volume
        @file_blocks + @next_volume.all_file_blocks
      else
        @file_blocks
      end
      
      @all_file_blocks = result if @is_first_volume
      result
    end
  
  private
  
    # Checks archive for it's contents. Rar-files are made up of multiple blocks 
    # which all have a variable length header with different fields. All archives
    # begin with a marker block and then an archive block. Each block may have
    # additional contents at the end (ie file data). They can also have sub-blocks
    # but we don't handle any of those.
    # This method will populate the array named @file_blocks. It will loop through
    # all of the archive's blocks and put any file blocks in @file_blocks.
    def list_contents!
      @fh.rewind
      @file_blocks = []

      begin
        loop do
          block = parse_header
          @file_blocks << block if block[:type] == :file
        end
      rescue EOFError
      end

      @next_volume = self.class.open(filename_for_next_volume) if @is_volume && @more_volumes
    end
    
    def filename_for_next_volume
      new_ext = case @fh.path
      when /\.part(\d+)\.rar$/
        ".part#{$1.succ}.rar"
      when /\.r(\d+)$/
        ".r#{$1.succ}"
      when /\.rar$/
        ".r00"
      else
        raise RarFileError, 'Unsupported file naming'
      end
    
      # concats string of everything up until beginning of regex-match + new ext
      "#{$`}#{new_ext}"
    end
  
    # The different block types we handle are marker, archive, file and eof.
    # There are other, more uncommon types but some of them can be skipped if
    # a flag is set in the header. NotImplementedError will be raised elsewise.
    def parse_header
      block = {}
      parse_basic_header(block)
      
      case block[:type]
      when :marker
        # do nothing
      when :archive
        @is_volume = block[:flags] & 0x1 != 0
        @is_first_volume = block[:flags] & 0x100 != 0
      when :file
        parse_file_header(block)
      when :eof
        @more_volumes = block[:flags] & 0x01 != 0
        raise EOFError
      else
        raise NotImplementedError, 'Unsupported block type' unless block[:skip_if_unknown]
      end
      
      block[:block_ending] = block[:header_ending] + (block[:data_size] || 0)
      # Now skip past the rest of the block so we can begin reading a new one
      @fh.seek(block[:block_ending], IO::SEEK_SET)
      block
    end
    
    def parse_basic_header(block)
      block[:block_start] = @fh.tell
      self.class.assign_block_fields(@fh.read(7).unpack("vCvv"), block, BASIC_FIELDS)
      block[:data_size] = @fh.read(4).unpack("V")[0] if block[:flags] & 0x8000 != 0
      block[:type] = BLOCK_TYPES[block[:type] - 0x72]
      block[:skip_if_unknown] = block[:flags] & 0x4000 != 0
      block[:header_ending] = block[:block_start] + block[:header_size]
    end
    
    def parse_file_header(block)
      self.class.assign_block_fields(@fh.read(21).unpack("VCVVCCvV"), block, FILE_FIELDS)
      if block[:flags] & 0x100 != 0
        block[:data_size] += @fh.read(4).unpack("V")[0] << 32
        block[:unpacked_size] += @fh.read(4).unpack("V")[0] << 32
      end
      block[:filename] = @fh.read(block[:name_length]).unpack("a*")[0]
      block[:continued_from_prev] = block[:flags] & 0x1 != 0
      block[:continues_in_next] = block[:flags] & 0x2 != 0
      # TODO: unsure about this, maybe it's in the file attrs (and different depending on block[:os])
      block[:is_dir] = block[:flags] & 0xe0 == 0
      block[:pack_method] -= 0x30 # becomes 0..5
      raise NotImplementedError, 'Unsupported pack method' if block[:pack_method] != 0 # no encrypytion/compression
      block[:os] = OSES[block[:os]]
      block[:file_time] = self.class.convert_msdos_time(block[:file_time])
      
      # Letting every file block have a reference to it's file object
      # makes it very easy to read from multiple volumes
      block[:file_handle] = @fh
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
  require 'pp'
  
  RarFile.open(ARGV.pop) do |rar|
    names = rar.filenames
    pp rar
    pp names
    pp rar.filesize(names.first)
    pp rar.read(names.first)[0, 100]
  end
end