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
    context "trim_after_last_delimiter without matching delimiter" do
      it "return empty string" do
        buf = @api.read_partial("gs://gcp-public-data-landsat/index.csv.gz", limit: 1, trim_after_last_delimiter: "x00")
        expect(buf.bytesize).to eql(0)
      end
    end
  end

  describe "list_objects" do
    before do
      skip "credential required." unless @credential_available
      @api = Gcs.new(@email, @private_key)
    end
    let(:root_items){ ["index.csv.gz"] }
    let(:root_prefixes){ %w{ LC08/ LE00/ LE07/ LM01/ LM02/ LM03/ LM04/ LM05/ LO08/ LT00/ LT04/ LT05/ LT08/ } }
    let(:lc08_items){ ["LC08/01_$folder$"] }
    let(:lc08_prefixes){ %w{ LC08/01/ LC08/PRE/ } }
    context "with bucket and empty prefix" do
      it "return items and prefixes" do
        res = @api.list_objects("gcp-public-data-landsat", prefix: "")
        expect(res.items.map(&:name)).to eql(root_items)
        expect(res.prefixes).to eql(root_prefixes)
        res = @api.list_objects("gcp-public-data-landsat", prefix: "LC08/")
        expect(res.items.map(&:name)).to eql(lc08_items)
        expect(res.prefixes).to eql(lc08_prefixes)
      end
    end
    context "with GCS URL" do
      it "return items and prefixes" do
        res = @api.list_objects("gs://gcp-public-data-landsat/")
        expect(res.items.map(&:name)).to eql(root_items)
        expect(res.prefixes).to eql(root_prefixes)
        res = @api.list_objects("gs://gcp-public-data-landsat/LC08/")
        expect(res.items.map(&:name)).to eql(lc08_items)
        expect(res.prefixes).to eql(lc08_prefixes)
      end
    end
  end

  describe "#glob" do
    before do
      skip "credential required." unless @credential_available
      @api = Gcs.new(@email, @private_key)
    end
    let(:pattern){ "gs://gcp-public-data-landsat/LC08/01/101/240/*/*.TIF" }
    it "yields matched objects" do
      items = []
      @api.glob(pattern) {|obj| items << obj.name }
      expect(items.size).to eql(108)
      expect(items.all?{|name| File.fnmatch("LC08/01/101/240/*/*.TIF", name) }).to be(true)
    end
  end
end
