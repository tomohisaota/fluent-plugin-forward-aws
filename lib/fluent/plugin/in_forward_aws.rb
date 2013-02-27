class Fluent::ForwardAWSInput < Fluent::Input
  Fluent::Plugin.register_input('forward-aws', self)

  # config_param :hoge, :string, :default => 'hoge'

  def initialize
    super
    require 'aws-sdk'
    require 'zlib'
    require 'tempfile'
    require 'json'
    @locker = Mutex::new
  end

  config_param :channel, :string, :default => "default"

  config_param :aws_access_key_id, :string, :default => nil
  config_param :aws_secret_access_key, :string, :default => nil
  
  config_param :aws_s3_endpoint, :string, :default => nil
  config_param :aws_s3_bucketname, :string, :default => nil
  config_param :aws_s3_skiptest, :bool, :default => false
  
  config_param :aws_sqs_endpoint, :string, :default => nil
  config_param :aws_sqs_queue_url, :string, :default => nil
  config_param :aws_sqs_skiptest, :bool, :default => false
  
  # Not documented parameters. Subject to change in future release
  config_param :aws_sqs_process_interval, :integer, :default => 1
  config_param :aws_sqs_monitor_interval, :integer, :default => 10
  config_param :aws_s3_testobjectname, :string, :default => "Config Check Test Object"
  config_param :start_thread, :bool, :default => true
  
  def configure(conf)
    super
    unless /[\w]+/ =~ @channel
      raise Fluent::ConfigError.new("channel is invalid. Exp=[\w]+")
    end
    unless @aws_access_key_id
      raise Fluent::ConfigError.new("aws_access_key_id is required")
    end
    unless @aws_secret_access_key
      raise Fluent::ConfigError.new("aws_secret_access_key is required")
    end
    unless @aws_s3_endpoint
      raise Fluent::ConfigError.new("aws_s3_endpoint is required")
    end
    unless @aws_s3_bucketname
      raise Fluent::ConfigError.new("aws_s3_bucketname is required")
    end
    unless @aws_sqs_endpoint
      raise Fluent::ConfigError.new("aws_sqs_endpoint is required")
    end
    unless @aws_sqs_queue_url
      raise Fluent::ConfigError.new("aws_sqs_queue_url is required")
    end
    unless(@aws_s3_skiptest)
      init_aws_s3_bucket()
      begin
        @bucket.objects[@aws_s3_testobjectname].write("TEST", :content_type => 'text/plain')
      rescue
        raise Fluent::ConfigError.new("Cannot put object to S3. Need s3:PutObject permission for resource arn:aws:s3:::" + @aws_s3_bucketname+"/*")
      end
    end
    unless(@aws_sqs_skiptest)
      init_aws_sqs_queue()
      begin
        @queue.receive_message() do |msg|
        end
      rescue => e
        raise Fluent::ConfigError.new("Cannot fetch queue from SQS. Need sqs:ReceiveMessage sqs:DeleteMessage permission for resource " + @aws_sqs_queue_url)
      end
    end
  end
  
  def start
    super
    init_aws_s3_bucket()
    init_aws_sqs_queue()
    if(@start_thread)
      @thread = Thread.new(&method(:run))
    end
  end

  def run
    @running = true
    while true
      msg = @queue.receive_message()
      if msg
        if(process(JSON.parse(msg.as_sns_message.body)))
          msg.delete()
        end
        sleep @aws_sqs_process_interval
        @locker.synchronize do
          return unless @running
        end
        next
      end
      sleep @aws_sqs_monitor_interval
      @locker.synchronize do
        return unless @running
      end
    end
  rescue => e
    puts e 
  end

  def process(msg)
    if msg["type"] == "ping"
      # Ignore ping message
      return true
    end
    if msg["type"] == "out"
      if msg["bucketname"] != @aws_s3_bucketname
        # Cannot process logs in other buckets
        return false
      end
      tmpFile = Tempfile.new("forward-aws-")
      begin
        #Download log file to temporary file
        @bucket.objects[msg["path"]].read do |chunk|
          tmpFile.write(chunk)
        end
        tmpFile.close()
        #gunzip and decode log file
        streamUnpacker = MessagePack::Unpacker.new()
        Zlib::GzipReader.open(tmpFile) {|reader|
          streamUnpacker.feed(reader.read())
          streamUnpacker.each {|event|
            (tag, time, record) = event
            Fluent::Engine.emit(tag,time,record)
          }
        }
        return true
      ensure
        tmp.close(true) rescue nil
      end
    end
    # Unknown notification. Do not delete
    return false
  end

  def shutdown
    super
    # Stop Thread and join
    @locker.synchronize do
      @running = false
    end
    if(@thread)
      @thread.run
      @thread.join
      @thread = nil
    end
  end
  
  private
  
  def check_aws_credential
    unless @aws_access_key_id
      raise Fluent::ConfigError.new("aws_access_key_id is required")
    end
    unless @aws_secret_access_key
      raise Fluent::ConfigError.new("aws_secret_access_key is required")
    end
  end
  
  private
  
  def init_aws_s3_bucket
    unless @bucket
      options = {}
      options[:access_key_id]      = @aws_access_key_id
      options[:secret_access_key]  = @aws_secret_access_key
      options[:s3_endpoint]        = @aws_s3_endpoint
      options[:use_ssl]            = true
      s3 = AWS::S3.new(options)
      @bucket = s3.buckets[@aws_s3_bucketname]
    end
  end
  
  def init_aws_sqs_queue
    unless @queue
      options = {}
      options[:access_key_id]      = @aws_access_key_id
      options[:secret_access_key]  = @aws_secret_access_key
      options[:sqs_endpoint]       = @aws_sqs_endpoint
      sqs = AWS::SQS.new(options)
      @queue = sqs.queues[@aws_sqs_queue_url]
    end
  end
end