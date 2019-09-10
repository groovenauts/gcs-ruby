require "spec_helper"

describe Gcs::GcsWriter do
  before do
    @gcs_api = double(:gcs_api)
    @session_url = "https://www.example.com/path?session=xxxxx"
    @http = double(:http)
    allow(@gcs_api).to receive(:initiate_resumable_upload).and_return(@session_url)
    expect(Net::HTTP).to receive(:new).with("www.example.com", 443).and_return(@http)
    allow(@http).to receive(:start).and_yield(@http)
    allow(@http).to receive(:use_ssl=).with(true)
    @writer = Gcs::GcsWriter.new(@gcs_api, "gs://mybucket/myobject")
  end

  describe "#start" do
    it "yield block and ensure to close" do
      res = double(:res, code: "201")
      expect(@http).to receive(:put).with("/path?session=xxxxx", "", {"Content-Range" => "bytes */0", "Content-Length" => "0" }).and_return(res)
      @writer.start do |o|
        expect(o).to be(o)
      end
    end
  end

  describe "#write" do
    context "write string under chunk size" do
      before do
        @writer.write("foo")
      end
      it "flush buffer at close" do
        res = double(:res, code: "201")
        expect(@http).to receive(:put).with("/path?session=xxxxx", "foo", {"Content-Range" => "bytes 0-2/3", "Content-Length" => "3" }).and_return(res)
        @writer.close
      end
    end

    context "write string larger than chunk size" do
      it "write 2 chunks" do
        buf = "a" * Gcs::GcsWriter::CHUNK_SIZE + "b"
        res = double(:res, code: "308")
        expect(@http).to receive(:put).with("/path?session=xxxxx", "a" * Gcs::GcsWriter::CHUNK_SIZE, {"Content-Range" => "bytes 0-#{Gcs::GcsWriter::CHUNK_SIZE-1}/*", "Content-Length" => Gcs::GcsWriter::CHUNK_SIZE.to_s }).and_return(res)
        @writer.write(buf)

        # remaining buffer should be flushed at `close`
        res = double(:res, code: "201")
        expect(@http).to receive(:put).with("/path?session=xxxxx", "b", {"Content-Range" => "bytes #{Gcs::GcsWriter::CHUNK_SIZE}-#{Gcs::GcsWriter::CHUNK_SIZE}/#{Gcs::GcsWriter::CHUNK_SIZE+1}", "Content-Length" => "1" }).and_return(res)
        @writer.close
      end
    end
  end
end
