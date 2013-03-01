# Fluent::Plugin::Forward-AWS

Forward-AWS plugin forwards log through Amazon Web Service.  
It uses S3 as log storage, and SNS+SQS for notification.  

Please see [wiki](https://github.com/tomohisaota/fluent-plugin-forward-aws/wiki/Forward-AWS-plugin-concept) to understand the concept.

## Installation

Use ruby gem as :

    $ gem install fluent-plugin-forward-aws

Or, if you're using td-client, you can call td-client's gem

    $ /usr/lib64/fluent/ruby/bin/gem install fluent-plugin-forward-aws

## AWS Configuration
### IAM
It is recommended to create IAM user for logging.  
Create IAM user with credential, and memorize following parameters
+ aws_access_key_id
+ aws_secret_access_key

### S3
Create bucket, and memorize following parameters
+ aws_s3_endpoint
+ aws_s3_bucketname

### SNS
Create SNS Topic, and memorize following parameters
+ aws_sns_endpoint
+ aws_sns_topic_arn 

### SQS
Create SQS Queue, subscribe to SNS, and memorize following parameters
+ aws_sqs_endpoint
+ aws_sqs_queue_url 

### How to configure SQS as SNS subscriber
In short, change SQS's access policy to accept "SendMessage" from your SNS ARN, And add SQS ARN to SNS subscribers. 
You can do the above step in one shot from SQS Management Console.  
For more detail, check [amazon official document](http://docs.aws.amazon.com/sns/latest/gsg/SendMessageToSQS.html)

## Common Configuration
### Parameters
 name                 | type                            | description
----------------------|---------------------------------|---------------------------
type                  | string (required)               | type of plugin should be **forward_aws**
aws_access_key_id     | string (required)               |  AWS Acccess Key ID
aws_secret_access_key | string (required)               | AWS Secket Access Key
aws_s3_endpoint       | string (required)               | [s3 Endpoint](http://docs.aws.amazon.com/general/latest/gr/rande.html#s3_region) for your bucket
aws_s3_bucketname     | string (required)               | S3 Bucketname
aws_s3_skiptest       | bool (default = false)          | Skip S3 Related test at startup
add_tag_prefix        | string (default = nil)          | Add specified prefix to tag before processing log
remove_tag_prefix     | string (default = nil)          | Remove specified prefix from tag before processing log
channel               | string (default = "default")    | Tag that Forward-AWS plugin uses for grouping logs.

## Out Plugin Configuration
### Parameters
 name                 | type                            | description
----------------------|---------------------------------|---------------------------
aws_sns_endpoint      | string (required)               | [SNS Endpoint](http://docs.aws.amazon.com/general/latest/gr/rande.html#sns_region) for your topic
aws_sns_topic_arn     | string (required)               | SNS Topic ARN
aws_sns_skiptest      | bool (default = false)          | Skip SNS Related test at startup

###Required AWS permission 
+ s3:PutObject
+ sns:Publish

### Basic configuration
Use "default" channel for all the log data.  
```
<match **>
  type forward_aws
  aws_access_key_id     XXXXXXXXXXXXXXXXXXXX
  aws_secret_access_key XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

  aws_s3_endpoint       s3-ap-northeast-1.amazonaws.com
  aws_s3_bucketname     XXXXXXXXXXXXXXXXXXXX

  aws_sns_endpoint      sns.ap-northeast-1.amazonaws.com
  aws_sns_topic_arn     arn:aws:sns:ap-northeast-1:XXXXXXXXXXXXXXXXXXXX

  # Time Sliced Output options
  buffer_path           /var/log/td-agent/buffer/forward_aws
  time_slice_wait       1m
  time_slice_format     %Y/%m/%d/%H/%M
  utc
  flush_at_shutdown     true
</match>
```

### Advanced configuration using forest plugin
Use tag as forward-AWS channel
```
<match **>
  type forest
  subtype forward_aws
  <template>
    channel               ${tag}
    aws_access_key_id     XXXXXXXXXXXXXXXXXXXX
    aws_secret_access_key XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

    aws_s3_endpoint       s3-ap-northeast-1.amazonaws.com
    aws_s3_bucketname     XXXXXXXXXXXXXXXXXXXX

    aws_sns_endpoint      sns.ap-northeast-1.amazonaws.com
    aws_sns_topic_arn     arn:aws:sns:ap-northeast-1:XXXXXXXXXXXXXXXXXXXX

    # Time Sliced Output options
    buffer_path           /var/log/td-agent/buffer/forward_aws-${tag}
    time_slice_wait       1m
    time_slice_format     %Y/%m/%d/%H/%M
    utc
    flush_at_shutdown     true
  </template>
</match>
```

## In Plugin Configuration
### Parameters

 name                 | type                            | description
----------------------|---------------------------------|---------------------------
aws_sqs_endpoint      | string (required)               | [SQS Endpoint](http://docs.aws.amazon.com/general/latest/gr/rande.html#sqs_region) for your topic
aws_sqs_queue_url     | string (required)               | SQS Queue URL (not ARN)
aws_sqs_skiptest      | bool (default = false)          | Skip SQS Related test at startup
channelEnableRegEx    | bool (default = false)          | Enabled Regular Expression when checking channel
dry_run               | bool (default = false)          | Do not delete notification after processing

###Required AWS permission 
+ s3:GetObject
+ sqs:ReceiveMessage
+ sqs:DeleteMessage

### Basic configuration
Default config is to listen to "default" channel.
```
<source>
  type forward_aws
  aws_access_key_id     XXXXXXXXXXXXXXXXXXXX
  aws_secret_access_key XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

  aws_s3_endpoint       s3-ap-northeast-1.amazonaws.com
  aws_s3_bucketname     XXXXXXXXXXXXXXXXXXXX
  
  aws_sqs_endpoint      sqs.ap-northeast-1.amazonaws.com
  aws_sqs_queue_url     https://sqs.ap-northeast-1.amazonaws.com/XXXXXXXXXXXXXXXXXXXX
</source>
```

### Advanced configuration
Use regex to filter channel
```
<source>
  type forward_aws
  channel .*
  channelEnableRegEx true
  aws_access_key_id     XXXXXXXXXXXXXXXXXXXX
  aws_secret_access_key XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

  aws_s3_endpoint       s3-ap-northeast-1.amazonaws.com
  aws_s3_bucketname     XXXXXXXXXXXXXXXXXXXX
  
  aws_sqs_endpoint      sqs.ap-northeast-1.amazonaws.com
  aws_sqs_queue_url     https://sqs.ap-northeast-1.amazonaws.com/XXXXXXXXXXXXXXXXXXXX
</source>
```

## Tips
### How to delete buffer objects on S3
Forward-AWS plugin do not delete buffer objects on S3.  
Use [S3's lifecycle management](http://docs.aws.amazon.com/AmazonS3/latest/dev/manage-lifecycle-using-console.html) to automatically archive or delete old buffer objects.

### How to use buffer objects as raw input
Each buffer object is msgpack stream object with gzip compression.

### Want to forward log per minute, but have archive per day
You can configure forward per minute, and setup another receiver for archiving.

### Skipping test at startup
You can control startup test by following optional parameters. Default value is false
+ aws_s3_skiptest
+ aws_sns_skiptest
+ aws_sqs_skiptest


## Contributing
I am newbie for both of Ruby and Fluentd.  
Feel free to send me pull request.  

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## Copyright

Copyright:: Copyright (c) 2013 Tomohisa Ota
License::   Apache License, Version 2.0
