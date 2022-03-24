#TODO kill stuff
#TODO as the following code is a mix of different versions (using various types for the buffer, meaning it likely won't run at all as it is);
#     some parts might even come straight from ruby and have been never run with crystal

class IO::Memory
  def add (data)
    oldPos= pos
    self.pos= size
    write data
    self.pos= oldPos
    self
  end

  def left
    size-pos
  end

  def get (n)
    raise SomeConnection::BufferTooShort.new if n > left
    s= Bytes.new n
    read s
    s
  end

  def byte : UInt8
    raise SomeConnection::BufferTooShort.new if 1 > left
    read_byte||0_u8
  end
end #TODO this shouldn't stay here, but moved to the other IO::M things

abstract class SomeConnection
  class BufferTooShort < Exception
  end

  setter pos=0

  def int : Int32
    r= [byte]
    until r[-1]<0x80
      r << byte
    end
    r.map_with_index{|x, i| ((x.to_i32%0x80) << 7*i).as(Int32)}.sum # 0_i32
  end

  def bytes7
    a= [byte]
    until a[-1]<0x80
      a[-1]%= 0x80
      a << byte
    end
    a
  end

  def message
    id= byte
    until id > 0
      id = byte
    end
    Remi.getMsgClass id, self
  end
end

class SecureConnection < SomeConnection
  class ConnectionClosed < Exception
  end

  def initialize (@rawConnection : TCPSocket, @connection : Remi::Relay::Connection)
    @buffer= IO::Memory.new
    @secure= false
    @bs= 16
    @kill= false
  end

  def kill
    unless killed
      @connection.kill
      @kill= true
      @rawConnection.close
    end
  end

  def killed
    @kill
  end

  def fetchRaw (io, wait=true)
    oldPos= io.pos
    oldSize= io.size
    io.pos= io.size
    loop do
      if killed
        io.pos= oldPos
        return
      end
      slice = Bytes.new @bs
      x_= LibC.recv(@rawConnection.fd, slice, slice.size, 0).to_i32
      case x_
      when (-1)
        unless wait && io.size==oldSize
          io.pos= oldPos
          return
        end
      when 0
        kill
      else
        x= slice[0...x_]
        if @secure
          p ["Attention: encrypted size < bs"] if x_<@bs
          x= readCipher.update(x)
        end
        io.write x
      end
    end
  end

  def get (n)
    loop do #kill stuff
      begin
        return @buffer.get n
      rescue ex : BufferTooShort
        fetchRaw @buffer
      end
    end
  end

  def byte
    loop do #kill stuff
      begin
        return @buffer.byte
      rescue ex : BufferTooShort
        fetchRaw @buffer
      end
    end
  end

  def clean
    while @buffer[@pos]?||0 != 0
      @pos+= 1
    end
  end

  def bam!
    @buffer= @buffer[@pos..-1]
    @pos= 0
    nil
  end

  def close
    @rawConnection.close
  end

  def secure (iK, iIV, oK, oIV, &notificationAction)
    @bs= oK.size
    @writeCipher= OpenSSL::Cipher.new("aes-#{@bs*8}-cbc")
    writeCipher.encrypt
    writeCipher.iv= oIV
    writeCipher.key= oK
    writeCipher.padding= false
    @readCipher= OpenSSL::Cipher.new("aes-#{@bs*8}-cbc")
    readCipher.decrypt
    readCipher.iv= iIV
    readCipher.key= iK
    readCipher.padding= false
    fetchRaw @buffer, false
    notificationAction.call if notificationAction
    @secure= true
  end

  def readCipher
    @readCipher.as(OpenSSL::Cipher)
  end

  def writeCipher
    @writeCipher.as(OpenSSL::Cipher)
  end

  def sendMsg (x)
    x= x.serialize if x.is_a? Remi::Msg
    return if x.empty?
    if @secure
     x0= Bytes.new size: (x.size/@bs.to_f).ceil.to_i*@bs
     x.copy_to x0
     x= writeCipher.update x0
    end
    sendRaw x
  end

  def sendRaw (x)
    return if killed || x.empty?
    x= x.serialize if x.is_a? Remi::Msg
    @rawConnection.write x
  end
end

class PseudoConnection < SomeConnection
  @buffer = uninitialized Slice(UInt8)
  def initialize (buffer : Bytes)
    @buffer= buffer
    @pos= 0_u32
  end

  def get (n=1)
    loop do
      begin
        raise BufferTooShort.new if left < n
        break
      rescue BufferTooShort
        fetch
      end
    end
    @buffer[@pos...(@pos+=n)]
  end

  def byte
    raise BufferTooShort.new if left==0
    @pos+= 1
    @buffer[@pos-1]
  end

  def fetch (x= nil)
    raise "That's it. There isn't any left."
  end

  def left
    @buffer.size-@pos
  end

  def sendMsg (x)
    puts "Pseudo sending a message… Done (as it's just skipped)."
  end

  def kill
    puts "Pseudo killing (ergo noone was harmed)."
  end

  def clean
  end

  def bam!
    @buffer= @buffer[@pos..-1]
    @pos= 0
    nil
  end
end

class ZeroConnection < PseudoConnection
  def initialize
    @pos= 0_u32
  end

  def get (n)
    Slice.new(n, 0_u8)
  end

  def byte
    0_u8
  end
end

Zeros= ZeroConnection.new
