# gcs-ruby

[![Build Status](https://travis-ci.org/groovenauts/gcs-ruby.svg?branch=master)](https://travis-ci.org/groovenauts/gcs-ruby)

Groovenauts' wrapper library for Google Cloud Storage with [google-api-ruby-client](https://github.com/google/google-api-ruby-client).

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'gcs'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install gcs

## Usage

```
gcs = Gcs.new(email_address, private_key)

# get bucket list
gcs.bucket(project_id)

# get object list
gcs.list_objects("myBucket", prefix: "path/to/subdir", max_results: 1000)

# get object metadata
get_object "myBucket", "myObject"
get_object "gs://myBucket/myObject"

# download object content
io = StringIO.new
get_object "myBucket", "myObject", download_dest: io
get_object "gs://myBucket/myObject", download_dest: io

# delete object
gcs.delete_object("myBucket", "myObject")
gcs.delete_object("gs://myBucket/myObject")

# create new object
io = StringIO.new("Hello, World!\")
gcs.insert_object("myBucket", "myObject", io)

# copy recursively
gcs.copy_tree("gs://myBucket1/src", "gs://myBucket2/dest")

# delete recursively
gcs.remove_tree("gs://myBucket/dir")

# read object content with size limitation
gcs.read_partial("gs://myBucket/myObject", limit: 1024) # => read first part of object at least 1024 bytes.
gcs.read_partial("myBucket", "myObjet", limit: 1024)
gcs.read_partial("gs://myBucket/myObject", limit: 1024, trim_after_last_delimiter: "\n") #=> remove substr after last "\n"

# initiate resumable upload
# return session URL to upload object content by PUT method requests.
# see https://cloud.google.com/storage/docs/json_api/v1/how-tos/resumable-upload
# origin_domain keyword arg was for CORS setting.
gcs.initiate_resumable_upload("myBucket", "myObject", content_type: "text/plain", origin_domain: "http://example.com")
gcs.initiate_resumable_upload("gs://myBucket/myObject", content_type: "text/plain", origin_domain: "http://example.com")
```

