# coding: utf-8

require "net/http"

class Gcs
  class GcsWriter
    # GCS resumable upload chunk size should be 256 KB (https://cloud.google.com/storage/docs/json_api/v1/how-tos/resumable-upload#example_uploading_the_file)
    class ServerError < RuntimeError
    end
    CHUNK_SIZE = 256 * 1024

    def initialize(gcs_api, bucket, object=nil, content_type: "application/octet-stream", origin_domain: nil)
      @session_url = gcs_api.initiate_resumable_upload(bucket, object, content_type: content_type, origin_domain: origin_domain)
      @pos = 0
      @buf = "".force_encoding(Encoding::ASCII_8BIT)
      uri = URI(@session_url)
      @path = uri.path + "?" + uri.query
      @http = Net::HTTP.new(uri.host, uri.port)
      @http.use_ssl = true
      @closed = false
    end

    attr_reader :pos, :closed
    alias :closed? :closed

    def start(&blk)
      begin
        blk.call(self)
      ensure
        close
      end
    end

    def put_chunk
      len = [CHUNK_SIZE, @buf.bytesize].min
      send_buf = @buf[0, len]
      if len < CHUNK_SIZE
        total_size = @pos + len
        closed = true
      else
        total_size = "*"
        closed = false
      end
      if len == 0
        range = "*"
      else
        range = "#{@pos}-#{@pos+len-1}"
      end
      res = @http.start{|h|
        h.put(@path, send_buf, {"Content-Range" => "bytes #{range}/#{total_size}", "Content-Length" => "#{len}" })
      }
      if closed
        expected_code = [200, 201]
      else
        expected_code = [308]
      end
      # see 'Handling errors' section in https://cloud.google.com/storage/docs/json_api/v1/how-tos/resumable-upload#handling_errors
      unless expected_code.include?(res.code.to_i)
        if res.code.to_i > 500
          raise ServerError, "server error at putting a chunk in resumable upload: status=#{res.code}\n" + res.body.to_s
        else
          raise "Unexpected error at putting a chunk in resumable upload: status=#{res.code}\n" + res.body.to_s
        end
      end
      @closed = closed
      @buf[0, len] = ""
      @pos += len
    end

    def close
      unless @closed
        put_chunk
      end
    end

    def write(str)
      if @closed
        raise "Write to closed stream."
      end
      @buf << str.to_s.dup.force_encoding(Encoding::ASCII_8BIT)
      while @buf.bytesize >= CHUNK_SIZE
        put_chunk
      end
    end
  end
end
