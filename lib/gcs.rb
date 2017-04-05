# coding: utf-8

require "gcs/version"
require "google/apis/storage_v1"

module Gcs
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

  def _ensure_bucket_object(bucket, object)
    if object.nil? and bucket.start_with?("gs://")
      uri = URI(bucket)
      bucket = uri.host
      object = uri.path[1..-1]
    end
    return [bucket, object]
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

  def list_objects(bucket, delimiter: "/", prefix: "", page_token: nil, max_results: nil)
    @api.list_objects(bucket, delimiter: delimiter, prefix: prefix, page_token: page_token, max_results: max_results)
  end

  def delete_object(bucket, object)
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

  def copy_tree(src, dest)
    src_url = URI(src)
    dest_url = URI(dest)
    src_bucket = src_url.host
    src_path = src_url.path[1..-1]
    dest_bucket = dest_url.host
    dest_path = dest_url.path[1..-1]
    src_path = src_path + "/" unless src_path[-1] == "/"
    dest_path = dest_path + "/" unless dest_path[-1] == "/"
    res = list_objects(src_bucket, prefix: src_path)
    (res.items || []).each do |o|
      next if o.name[-1] == "/"
      buf = StringIO.new("".b)
      get_object(src_bucket, o.name, download_dest: buf)
      dest_obj_name = dest_path + o.name.sub(/\A#{Regexp.escape(src_path)}/, "")
      insert_object(dest_bucket, dest_obj_name, buf)
    end
    (res.prefixes || []).each do |p|
      copy_tree("gs://#{src_bucket}/#{p}", "gs://#{dest_bucket}/#{dest_path}#{p.sub(/\A#{Regexp.escape(src_path)}/, "")}")
    end
  end

  def remove_tree(gcs_url)
    url = URI(gcs_url)
    bucket = url.host
    path = url.path[1..-1]
    path = path + "/" unless path[-1] == "/"
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
end
