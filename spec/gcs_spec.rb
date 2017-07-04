require "spec_helper"

describe Gcs do
  it "has a version number" do
    expect(Gcs::VERSION).not_to be nil
  end

  describe ".ensure_bucket_object" do
    describe "with bucket and object" do
      it do
        expect(Gcs.ensure_bucket_object("bucket", "Object")).to eql(["bucket", "Object"])
      end
    end

    describe "with GCS URL" do
      describe "ASCII Only" do
        it do
          expect(Gcs.ensure_bucket_object("gs://bucket/path/to/object")).to eql(["bucket", "path/to/object"])
        end
      end

      describe "Multi bytes characters in object name" do
        it do
          expect(Gcs.ensure_bucket_object("gs://bucket/path/to/\u3042")).to eql(["bucket", "path/to/\u3042"])
        end
      end
    end
  end

  describe "read_partial" do
    before do
      skip "credential required." unless @credential_available
      @api = Gcs.new(@email, @private_key)
    end
    it do
      buf = @api.read_partial("gs://gcp-public-data-landsat/index.csv.gz", limit: 100)
      expect(buf.bytesize).to be < 4*1024
    end
  end
end
