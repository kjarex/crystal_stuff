module Serialize
  def serialize
    io= IO::Memory.new
    serialize io
    io.to_slice
  end

  def serialize7
    io= IO::Memory.new
    serialize7 io
    io.to_slice
  end
end

module SerializeNum
  include Serialize
  
  macro included
    def self.from7 (sc : SomeConnection)
      sign sc.bytes7.reverse.reduce(utype.new 0){|e, c| (e<<7)+c}
    end

    def self.from (b : SomeConnection)
      sign sc.get(sizeof(self)).reverse!.reduce(utype.new 0){|e, c| (e<<8)+c}
    end

    def self.sign (x)
      x
    end

    def self.utype
      self
    end
  end

  def serialize7 (io)
    x = self
    v= unsigned #((UInt64::MAX>>(8-sizeof(typeof(x)))*8))&pointerof(x).as(Pointer(UInt64)).value
    until v<0x80
      io.write_byte (v%0x80+0x80).to_u8
      v>>= 7
    end
    io.write_byte v.to_u8
  end

  def serialize (io)
    to_io(io, IO::ByteFormat::LittleEndian) #TODO regarding Remi - check if we need BigEndian anywhere (but I don't think so; only possibility which comes to mind would be AccessToken!?)
  end

  def unsigned
    self
  end
end

struct UInt8
  include SerializeNum
end

struct UInt16
  include SerializeNum
end

struct UInt32
  include SerializeNum
end

struct UInt64
  include SerializeNum
end

struct Int8
  include SerializeNum

  def self.utype
    UInt8
  end

  def unsigned
    to_u8!
  end

  def self.sign (x)
    x.to_i8!
  end
end

struct Int16
  include SerializeNum

  def self.utype
    UInt16
  end

  def unsigned
    to_u16!
  end

  def self.sign (x)
    x.to_i16!
  end
end

struct Int32
  include SerializeNum

  def self.utype
    UInt32
  end

  def unsigned
    to_u32!
  end

  def self.sign (x)
    x.to_i32!
  end
end

struct Int64
  include SerializeNum

  def self.utype
    UInt64
  end

  def unsigned
    to_u64!
  end

  def self.sign (x)
    x.to_i64!
  end
end

struct Float32
  include SerializeNum
end #TODO 7bit stuff (maybe not required for Remi)

struct Float64
  include SerializeNum
end #TODO 7bit stuff (maybe not required for Remi)

#TODO if used for any purpose other than Remi, BigInt and/or BN support might be required 
