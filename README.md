# Fluent::Plugin::Forward-AWS

Still under development. Please come back later:-)

Forward-AWS plugin forwards log through Amazon Web Service.  
It uses S3 as log storage, and SNS+SQS for notification.  
See [wiki](https://github.com/tomohisaota/fluent-plugin-forward-aws/wiki) for more detail.

## Installation

Ruby gem is not yet supported...

Use ruby gem as :

    $ gem install fluent-plugin-forward-aws

Or, if you're using td-client, you can call td-client's gem

    $ /usr/lib64/fluent/ruby/bin/gem install fluent-plugin-forward-aws

## Configuration

### out plugin for forwarder
Put log on S3, and send notification through SNS.

[aws_key_id (required)] AWS access key id.

Required AWS permission 
*s3:PutObject
*sns:Publish
gitg
### in plugin for receiver
Listen to notification on SQS, and read log data from S3.

Required AWS permission 
*s3:GetObject
*sqs:ReceiveMessage
*sqs:DeleteMessage

### How to configure SQS as SNS subscriber
In short, change SQS's access policy to accept "SendMessage" from your SNS ARN, And add SQS ARN to SNS subscribers. 
You can do the above step in one shot from SQS Management Console.  
For more detail, check [amazon official document](http://docs.aws.amazon.com/sns/latest/gsg/SendMessageToSQS.html)

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## Copyright

Copyright:: Copyright (c) 2013 Tomohisa Ota
License::   Apache License, Version 2.0
