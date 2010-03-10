# RarFile - introduction

RAR is a proprietary archive file format. [Read more about it at Wikipedia](http://en.wikipedia.org/wiki/Rar). The compression algorithm is proprietary but the decompression can be found in unrar's source code. There is basically three versions of the format:

- RAR (Wikipedia says 1993 for format, WinRAR was released 1995)
- RAR2, used since version 1.50 (WinRAR 2 was released 1996)
- RAR3, used since 2.9 and by 3.0

WinRAR is the trialware graphical program, RAR is the shareware command-line program and unrar is the freeware command-line program with available source code. RAR and unrar can be found at http://www.rarlab.com/rar_add.htm.


## Goals

This code targets the RAR2 version of the format. The code supports split archives but not compressed or encrypted archives. Only the "store" method for compression is supported. A lot of other features of the format won't be implemented. The purpose is to be able to open the kind of rar-files that are common for [scene releases in filesharing networks](http://en.wikipedia.org/wiki/Standard_(warez\)). The goals:

- to be able to open rar-files in version 2 format
- won't ever modify or create archives
- not encrypted or compressed
- possibly split into multiple archives
- CRC checks won't be performed, the archive will be assumed to be fully   downloaded and OK
- file attributes won't have any effect
- comments will be ignored
- uses new or old file naming
- be able to list files and read their contents
- possibly handle directories (unsure about this)


## Examples

RarFile is minimal, has no dependencies and is platform-independent. It's implemented in the Ruby language. Look at the doc comments and regular comments for a detailed description of the format, features etc.

Do a quick check:

	RarFile.is_rar_file?(filename) # => true / false

Opening and reading:

	# Alias of #new. Works like File.open - can take a block, after which the file will be closed
	RarFile.open(filename) do |rar|
	  archived_files = rar.filenames # => ["file.txt", "another_file.txt"]
	  rar.filesize(archived_files.first) # => 1234
	  rar.read(archived_files.first) # => "Hello world!"
	end
	
	RarFile.new(not_a_rar_file) # will raise RarFile::NotARarFile < IOError

Inspecting:

	# Inspecting a RarFile-object will show more info about the archive
	
	require 'pp'
	RarFile.open(filename) do |rar|
	  rar.filenames # The object won't contain any data until a method has been called
	  pp rar
	end


## Resources used for writing this code

- Implementation ideas was taken from http://github.com/jphastings/unrar
- some simple, minimal Python code that can be found at   http://trac.opensubtitles.org/projects/opensubtitles/wiki/RarSourceCodes or https://bugs.launchpad.net/subdownloader/+bug/242696
- a document named [RAR version 2.02 - Technical information](http://libxad.cvs.sourceforge.net/viewvc/libxad/support/formats/RAR202.txt?revision=1.1&view=markup), that has been a tremendous help for understanding the format. Don't know the origins of the document.
- Most projects that extract rar-files use unrar. The code is in C++. From the readme: "source is subset of RAR and generated from RAR source automatically". It supports all 3 format versions and has a lot of other features which makes it a bit hard to read the code.
  - `headers.hpp`: is a good starting point. It has some constants and data structs for the file format's different "blocks" and "headers".
  - `arcread.cpp`, `archive.[ch]pp`: reads in bits from files and puts them in the block/header data structs.
  - `extract.[ch]pp`: when run from command-line `CmdExtract` will extract the file
  - `volume.cpp`: `MergeArchive` for opening split archives (I think)
  - `list.cpp`: prints info for archive, file headers etc
- http://www.unrarlib.org which can decompress the RAR2-format and is GPL. It's code is in C.
- http://hem.bredband.net/catacombae/jlrarx.html, a Java library which uses unrarlib as reference. GPL and pretty messy, but good anyway.

I've also used the calculator (programmer mode) and the hex editor [HexFiend.app](http://ridiculousfish.com/hexfiend/) for calculating and checking flags, bits, fields etc.


## License and Copyright

**New BSD License**

Copyright (c) 2009-2010, Johan Lundström
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

- Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
- Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
- Neither the name of the <organization> nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.