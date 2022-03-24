# very incomplete (but works enough for rudimentary testing)
@[Link(ldflags: "-lcubeSQL")]
lib LibCube
  fun cubesql_version() : LibC::Char*
  fun cubesql_affected_rows(db : LibC::Int*) : Int64
  fun cubesql_bind(db : LibC::Int*, sql : LibC::Char*, colValue : LibC::Char*, colSize : LibC::Int, colType : LibC::Int, ncols : LibC::Int ) : LibC::Int
  fun cubesql_cancel(db : LibC::Int*)
  fun cubesql_changes(db : LibC::Int*) : Int64
  fun cubesql_connect(csqldb : LibC::Int**, host : LibC::Char*, port : Int32, user : LibC::Char*, pass : LibC::Char*, timeOut : Int32, encryption : Int32) : Int32
  fun cubesql_connect_ssl(csqldb : LibC::Int**, host : LibC::Char*, port : Int32, user : LibC::Char*, pass : LibC::Char*, timeOut : Int32, encryption : Int32, sslCertificatePath : LibC::Char*) : Int32
  fun cubesql_cursor_free(csqlc : LibC::Int*)
  fun cubesql_cursor_numrows(csqlc : LibC::Int*) : LibC::Int
  fun cubesql_cursor_currentrow(csqlc : LibC::Int* ) : LibC::Int
  fun cubesql_cursor_numcolumns(csqlc : LibC::Int* ) : LibC::Int
  fun cubesql_cursor_int(csqlc : LibC::Int*, row : LibC::Int, column : LibC::Int, defaultValue : LibC::Int) : LibC::Int
  fun cubesql_cursor_double(csqlc : LibC::Int*, row : LibC::Int, column : LibC::Int, defaultValue : Float32) : Float32
  fun cubesql_cursor_int64(csqlc : LibC::Int*, row : LibC::Int, column : LibC::Int, defaultValue : Int64) : Int64
  fun cubesql_cursor_rowid(csqlc : LibC::Int*, row : LibC::Int) : Int64
  fun cubesql_cursor_field(csqlc : LibC::Int*, row : LibC::Int, column : LibC::Int, length : LibC::Int*) : UInt8*
  fun cubesql_cursor_seek(csqlc : LibC::Int*, index : LibC::Int) : LibC::Int
  fun cubesql_cursor_columntype(csqlc : LibC::Int*, index : LibC::Int) : LibC::Int
  fun cubesql_cursor_iseof(csqlc : LibC::Int* ) : LibC::Int
  fun cubesql_disconnect (csqldb : LibC::Int*, gracefully : Int32)
  fun cubesql_errmsg(db : LibC::Int*) : LibC::Char*
  fun cubesql_errcode(db : LibC::Int*) : LibC::Int
  fun cubesql_execute (db : LibC::Int*, sql : LibC::Char*) : LibC::Int
  fun cubesql_last_inserted_rowID(db : LibC::Int*) : Int64
  fun cubesql_ommit(db : LibC::Int*) : LibC::Int
  fun cubesql_ping(db : LibC::Int*) : LibC::Int
  fun cubesql_receive_data(db : LibC::Int*, length : LibC::Int, isEndChunk : LibC::Int) : LibC::Char*
  fun cubesql_rollback(db : LibC::Int*) : LibC::Int
  fun cubesql_setpath(type : Int32, path : LibC::Char*)
  fun cubesql_set_database(db : LibC::Int*, dbName : LibC::Char*) : LibC::Int
  fun cubesql_send_enddata(db : LibC::Int*) : LibC::Int
  fun cubesql_send_data(db : LibC::Int*, buffer : LibC::Char*, length : LibC::Int) : LibC::Int
  fun cubesql_select (db : LibC::Int*, sql : LibC::Char*, unused : Int32) : LibC::Int*
  fun cubesql_trace(db : LibC::Int*, ...)
  fun cubesql_vmprepare(db : LibC::Int*, sql : LibC::Char*) : LibC::Int*
  fun cubesql_vmbind_int(vm : LibC::Int*, index : LibC::Int, value : LibC::Int) : LibC::Int
  fun cubesql_vmbind_double(vm : LibC::Int*, index : LibC::Int, value : Float32) : LibC::Int
end

class CubeSQLException < Exception
end

class CubeSQL
  @db= Pointer(Int32).null
  DEFAULT_PORT    = 4430
  DEFAULT_TIMEOUT = 12
  DEFAULT_LANGUAGE= "DE"

  BIND_INTEGER  = 1;
  BIND_DOUBLE   = 2;
  BIND_TEXT     = 3;
  BIND_BLOB     = 4;
  BIND_NULL     = 5;
  BIND_INT64    = 8;
  BIND_ZEROBLOB = 9;

  enum Encryption
    None       = 0
    AES128     = 2
    AES192     = 3
    AES256     = 4
    SSL        = 8
    SSL_AES128 = SSL + AES128
    SSL_AES192 = SSL + AES192
    SSL_AES256 = SSL + AES256
  end

  NoError            =  0
  Error              = -1
  # MemoryError        = -2
  # ParameterError     = -3
  # ProtocolError      = -4
  # ZLibError          = -5
  # SSLError           = -6
  # SSLCertError       = -7
  # SSLDisabledError   = -8

  def initialize (host : String, user : String, pass : String, port : Int32= DEFAULT_PORT, timeOut : Int32= DEFAULT_TIMEOUT, encryption : Encryption= Encryption::None, sslCertificatePath : String= "")
      connect host, user, pass, sslCertificatePath, port, timeOut, encryption
  end

  def connect(host : String, userName : String, password : String, sslCertificatePath : String, port : Int32= DEFAULT_PORT, timeOut : Int32= DEFAULT_TIMEOUT, encryption : Encryption= Encryption::None) : Int32
    disconnect unless @db.null?
    @db= Pointer(Int32).malloc
    if sslCertificatePath.empty?
      result= LibCube.cubesql_connect pointerof(@db), host, port, userName, password, timeOut, encryption
    else
      result= LibCube.cubesql_connect_ssl pointerof(@db), host, port, userName, password, timeOut, encryption, sslCertificatePath
    end
    raise CubeSQLException.new "Connection failed (#{result})" if result==Error
    NoError
  end

  # def setPath (type : Int, path : String)
  #   LibCube.cubesql_setpath type, path
  # end

  def disconnect (gracefully : Bool = true)
    return if @db.null?
    LibCube.cubesql_disconnect @db, (gracefully ? 1 : 0)
    @db= Pointer(Int32).null
  end

  def finalize
    disconnect
  end

  def use (database : String, language : String= "DE")
    LibCube.cubesql_set_database @db, database
    LibCube.cubesql_execute @db, "SET CLIENT TYPE TO 'Crystal';"
    LibCube.cubesql_execute @db, "SET LANGUAGE TO #{DEFAULT_LANGUAGE};"
  end

  def version : String
    String.new(LibCube.cubesql_version).hexbytes.map{|b| b.to_s}.join(".")
  end

  def errorCode : Int
    LibCube.cubesql_errcode @db
  end

  def errorMessage : String
    String.new LibCube.cubesql_errmsg @db
  end

  def ping : Int
    LibCube.cubesql_ping @db
  end

  def commit : Int
    LibCube.cubesql_commit @db
  end

  def rollback : Int
   LibCube.cubesql_rollback @db
  end

  def cancel
    LibCube.cubesql_cancel @db
  end

  def affectedRows : Int64
    LibCube.cubesql_affected_rows @db
  end

  def lastInsertedRowID : Int64
    LibCube.cubesql_affected_rows @db
  end

  def execute (sql : String)
    result= LibCube.cubesql_execute @db, sql
    raise CubeSQLException.new "#{errorMessage} (#{errorCode})" if result==Error
  end

  def select (query : String) : CubeSQLResult
    csqlc= LibCube.cubesql_select @db, query, 0
    raise CubeSQLException.new "#{errorMessage} (#{errorCode})" if csqlc.null?
    CubeSQLResult.new csqlc
  end
end

class CubeSQLResult
  enum Type
    None
    Integer
    Float
    Text
    Blob
    Boolean
    Date
    Time
    Timestamp
    Currency
  end

  CURROW   = -1
  COLNAME  =  0
  COLTABLE = -2
  ROWID    = -666

  SEEKNEXT = -2;
  SEEKFIRST= -3;
  SEEKLAST = -4;
  SEEKPREV = -5;

  def initialize (@csqlc : Pointer(Int32))
  end

  def finalize
    LibCube.cubesql_cursor_free @csqlc
    @csqlc= Pointer(Int32).null
  end

  def getNumRows : Int
    LibCube.cubesql_cursor_numrows @csqlc
  end

  def getNumCols : Int
    LibCube.cubesql_cursor_numcolumns @csqlc
  end

  def titles
    (1..getNumCols).map{|col| getFieldAsString 0, col}
  end

  def columns
    (1..getNumCols).map{|col| {(getFieldAsString 0, col), (getColumnType col)}}
  end

  def types
    (1..getNumCols).map{|col| getColumnType col}
  end

  def getCurrentRow : Int
    LibCube.cubesql_cursor_currentrow @csqlc
  end

  def eof? : Bool
    LibCube.cubesql_cursor_iseof(@csqlc) == 1
  end

  def getColumnType (column : Int) : Int
   LibCube.cubesql_cursor_columntype @csqlc, column
  end

  def getFieldAsBytes (row : Int, column : Int) : Bytes?
    lp= Pointer(Int32).malloc
    result= LibCube.cubesql_cursor_field @csqlc, row, column, lp
    return nil if lp!=0 && result.null?
    Bytes.new result, lp.value
  end

  def getFieldAsString (row : Int, column : Int)
    x= getFieldAsBytes row, column
    return nil unless x
    String.new x
  end

  def getRowID (row : Int) : Int64
    LibCube.cubesql_cursor_rowid @csqlc, row
  end

  def getInt64Value (row : Int, column : Int, defaultValue : Int64) : Int64
    LibCube.cubesql_cursor_int64 @csqlc, row, column, defaultValue
  end

  def getIntValue (row : Int, column : Int, defaultValue : Int) : Int
    LibCube.cubesql_cursor_int @csqlc, row, column, defaultValue
  end

  def getDoubleValue (row : Int, column : Int, defaultValue : Float32) : Float32
    LibCube.cubesql_cursor_double @csqlc, row, column, defaultValue
  end

  def seek (index : Int) : Int
    LibCube.cubesql_cursor_seek @csqlc, index
  end

  def to_h
    (1...getNumRows).map do |row|
      row_ = Hash(String, Bobo).new
      columns.map_with_index(1){|c, i|
        t= Type.from_value c[1]
        row_[c[0].not_nil!]= case t
        when Type::Integer
          getIntValue row, i, 0
        when Type::Float
          getDoubleValue row, i, 0.to_f32
        when Type::Text
          getFieldAsString row, i
        when Type::Blob
          getFieldAsBytes row, i
        else
          "else #{t.to_s}"
        end}
      row_
    end
  end
end
