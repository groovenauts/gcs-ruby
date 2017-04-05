# gcs-ruby

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
gcs.remove_tree("gs://myBucket1/dir")
```

