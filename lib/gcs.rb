# coding: utf-8

require "net/http"
require "cgi"
require "json"

require "gcs/version"
require "google/apis/storage_v1"

class Gcs
  include Google::Apis::StorageV1
  def initialize(email_address = nil, private_key = nil, scope: "cloud-platform")
    @api = Google::Apis::StorageV1::StorageService.new
    scope_url = "https://www.googleapis.com/auth/#{scope}"
    if email_address and private_key
      auth = Signet::OAuth2::Client.new(
        token_credential_uri: "https://accounts.google.com/o/oauth2/token",
        audience: "https://accounts.google.com/o/oauth2/token",
        scope: scope_url,
        issuer: email_address,
        signing_key: private_key)
    else
      auth = Google::Auth.get_application_default([scope_url])
    end
    auth.fetch_access_token!
    @api.authorization = auth
  end

  def buckets(project_id)
    @api.list_buckets(project_id, max_results: 1000).items || []
  end

  def bucket(name)
    @api.get_bucket(name)
  rescue Google::Apis::ClientError
    if $!.status_code == 404
      return nil
    else
      raise
    end
  end

  def insert_bucket(project_id, name, storage_class: "STANDARD", acl: nil, default_object_acl: nil, location: nil)
    b = Bucket.new(
      name: name,
      storage_class: storage_class
    )
    b.location = location if location
    b.acl = acl if acl
    b.default_object_acl = default_object_acl if default_object_acl
    @api.insert_bucket(project_id, b)
  end

  def delete_bucket(name)
    @api.delete_bucket(name)
  rescue Google::Apis::ClientError
    if $!.status_code == 404
      return nil
    else
      raise
    end
  end

  def self.ensure_bucket_object(bucket, object=nil)
    if object.nil? and bucket.start_with?("gs://")
      bucket = bucket.sub(%r{\Ags://}, "")
      bucket, object = bucket.split("/", 2)
    end
    return [bucket, object]
  end

  def _ensure_bucket_object(bucket, object=nil)
    self.class.ensure_bucket_object(bucket, object)
  end

  def get_object(bucket, object=nil, download_dest: nil)
    bucket, object = _ensure_bucket_object(bucket, object)
    begin
      @api.get_object(bucket, object, download_dest: download_dest)
    rescue Google::Apis::ClientError
      if $!.status_code == 404
        return nil
      else
        raise
      end
    end
  end

  def read_partial(bucket, object=nil, limit: 1024*1024, trim_after_last_delimiter: nil, &blk)
    bucket, object = _ensure_bucket_object(bucket, object)
    uri = URI("https://www.googleapis.com/download/storage/v1/b/#{CGI.escape(bucket)}/o/#{CGI.escape(object).gsub("+", "%20")}?alt=media")
    Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      req = Net::HTTP::Get.new(uri.request_uri)
      req["Authorization"] = "Bearer #{@api.authorization.access_token}"
      http.request(req) do |res|
        case res
        when Net::HTTPSuccess
          if blk
            res.read_body(&blk)
            return res
          else
            total = "".force_encoding(Encoding::ASCII_8BIT)
            res.read_body do |part|
              total << part
              if total.bytesize > limit
                break
              end
            end
            if trim_after_last_delimiter
              i = total.rindex(trim_after_last_delimiter.force_encoding(Encoding::ASCII_8BIT))
              if i.nil?
                # If no delimiter was found, return empty string.
                # This is because caller expect not to incomplete line. (ex: Newline Delimited JSON)
                i = -1
              end
              total[(i+1)..-1] = ""
            end
            return total
          end
        when Net::HTTPNotFound
          return nil
        else
          raise "Gcs.read_partial failed with HTTP status #{res.code}: #{res.body}"
        end
      end
    end
  end

  def list_objects(bucket, delimiter: "/", prefix: "", page_token: nil, max_results: nil)
    @api.list_objects(bucket, delimiter: delimiter, prefix: prefix, page_token: page_token, max_results: max_results)
  end

  def delete_object(bucket, object=nil)
    bucket, object = _ensure_bucket_object(bucket, object)
    @api.delete_object(bucket, object)
  end

  # @param [String] bucket
  # @param [String] object name
  # @param [String|IO] source
  # @param [String] content_type
  # @param [String] content_encoding
  #
  # @return [Google::Apis::StorageV1::Object]
  def insert_object(bucket, name, source, content_type: nil, content_encoding: nil)
    bucket, name = _ensure_bucket_object(bucket, name)
    obj = Google::Apis::StorageV1::Object.new(name: name)
    @api.insert_object(bucket, obj, content_encoding: content_encoding, upload_source: source, content_type: content_type)
  end

  def rewrite(src_bucket, src_object, dest_bucket, dest_object)
    r = @api.rewrite_object(src_bucket, src_object, dest_bucket, dest_object)
    until r.done
      r = @api.rewrite_object(src_bucket, src_object, dest_bucket, dest_object, rewite_token: r.rewrite_token)
    end
    r
  end

  def copy_tree(src, dest)
    src_bucket, src_path = self.class.ensure_bucket_object(src)
    dest_bucket, dest_path = self.class.ensure_bucket_object(dest)
    src_path = src_path + "/" unless src_path[-1] == "/"
    dest_path = dest_path + "/" unless dest_path[-1] == "/"
    res = list_objects(src_bucket, prefix: src_path)
    (res.items || []).each do |o|
      next if o.name[-1] == "/"
      dest_obj_name = dest_path + o.name.sub(/\A#{Regexp.escape(src_path)}/, "")
      self.rewrite(src_bucket, o.name, dest_bucket, dest_obj_name)
    end
    (res.prefixes || []).each do |p|
      copy_tree("gs://#{src_bucket}/#{p}", "gs://#{dest_bucket}/#{dest_path}#{p.sub(/\A#{Regexp.escape(src_path)}/, "")}")
    end
  end

  def copy_object(src, dest)
    src_bucket, src_path = self.class.ensure_bucket_object(src)
    dest_bucket, dest_path = self.class.ensure_bucket_object(dest)
    self.rewrite(src_bucket, src_path, dest_bucket, dest_path)
  end

  def remove_tree(gcs_url)
    bucket, path = self.class.ensure_bucket_object(gcs_url)
    if path.size > 0 and path[-1] != "/"
      path = path + "/"
    end
    next_page_token = nil
    loop do
      begin
        res = list_objects(bucket, prefix: path, delimiter: nil, page_token: next_page_token)
      rescue Google::Apis::ClientError
        if $!.status_code == 404
          return nil
        else
          raise
        end
      end

      # batch request あたりの API 呼び出しの量は API の種類によって異なり
      # Cloud Storage JSON API のドキュメントでは 100 となってるけど1000でもいけたので1000に変更
      # ref. https://cloud.google.com/storage/docs/json_api/v1/how-tos/batch
      (res.items || []).each_slice(1000) do |objs|
        @api.batch do
          objs.each do |o|
            @api.delete_object(bucket, o.name) {|_, err| raise err if err and (not(err.respond_to?(:status_code)) or (err.status_code != 404))}
          end
        end
      end
      break unless res.next_page_token
      next_page_token = res.next_page_token
    end
  end

  def initiate_resumable_upload(bucket, object=nil, content_type: "application/octet-stream", origin_domain: nil)
    bucket, object = self.class.ensure_bucket_object(bucket, object)
    uri = URI("https://www.googleapis.com/upload/storage/v1/b/#{CGI.escape(bucket)}/o?uploadType=resumable")
    http = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      req = Net::HTTP::Post.new(uri.request_uri)
      req["content-type"] = "application/json; charset=UTF-8"
      req["Authorization"] = "Bearer #{@api.authorization.access_token}"
      req["X-Upload-Content-Type"] = content_type
      if origin_domain
        req["Origin"] = origin_domain
      end
      req.body = JSON.generate({ "name" => object })
      res = http.request(req)
      return res["location"]
    end
  end
end
