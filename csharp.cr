#NOTE works fine, but: no error handling has been done for possible issues (e.g. invalid time or blob); could be probably improved

require "openssl_rsa"

struct Time
  def self.csharp (t : UInt64)
    t0= t>>62==1 ? Time.utc(1, 1, 1) : Time.local(1, 1, 1)
    ts= (t&((1_u64 << 62)-1))//10**7
    t0+ts
  end
end

class OpenSSL::RSA
  def self.csharp (blob : String) #TODO maybe add other inputs; String is rather unlikely to be at hand
    io= IO::Memory.new
    Base64.decode blob, io
    io.pos= 12
    l= io.read_bytes Int32
    e= BigInt.new io.read_bytes Int32
    n, b, q, dmp1, dmq1, iqmp, d= [8, 16, 16, 16, 16, 16, 8].map{|l_| Array.new((l//l_),0).map{io.read_byte.not_nil!.to_i}.reverse.reduce(BigInt.new){|b, c| b*256+c}}
    OpenSSL::RSA.new l, e, n, b, q, dmp1, dmq1, iqmp, d
  end
end
