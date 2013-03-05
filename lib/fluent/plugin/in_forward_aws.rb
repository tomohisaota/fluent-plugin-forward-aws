class Fluent::ForwardAWSInput < Fluent::Input
  Fluent::Plugin.register_input('forward_aws', self)
  
  require_relative "forward_aws_util"
  include ForwardAWSUtil
    
  def initialize
    super
    require 'aws-sdk'
    require 'zlib'
    require 'tempfile'
    require 'json'
    @locker = Mutex::new
  end

  config_param :channel, :string, :default => "default"
  config_param :channelEnableRegEx, :bool, :default => false

  config_param :aws_access_key_id, :string, :default => nil
  config_param :aws_secret_access_key, :string, :default => nil
  
  config_param :aws_s3_endpoint, :string, :default => nil
  config_param :aws_s3_bucketname, :string, :default => nil
  config_param :aws_s3_skiptest, :bool, :default => false
  
  config_param :aws_sqs_endpoint, :string, :default => nil
  config_param :aws_sqs_queue_url, :string, :default => nil
  config_param :aws_sqs_skiptest, :bool, :default => false
  config_param :aws_sqs_wait_time_seconds,  :integer, :default => 5
  config_param :aws_sqs_limit,              :integer, :default => 10
  config_param :aws_sqs_visibilitiy_timeout,:integer, :default => 300
  
  config_param :add_tag_prefix, :string, :default => nil
  config_param :remove_tag_prefix, :string, :default => nil
  
  config_param :dry_run, :bool, :default => false
  
  # Not documented parameters. Subject to change in future release
  config_param :aws_sqs_process_interval,   :integer, :default => 0
  config_param :aws_sqs_monitor_interval,   :integer, :default => 25
  
  config_param :aws_s3_testobjectname, :string, :default => "Config Check Test Object"
  config_param :start_thread, :bool, :default => true
  
  
  def configure(conf)
    super
    if /^\s*$/ =~ @channel
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
        @queue.receive_message() do |notification|
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
      @thread = Thread.new(&method(:run)) unless @thread
    end
  end

  def run
    @running = true
    while true
      $log.debug "Long Polling SQS for #{@aws_sqs_wait_time_seconds} secs with message limit #{@aws_sqs_limit}"
      notificationRaws = @queue.receive_message({
        :limit               => @aws_sqs_limit,
        :wait_time_seconds   => @aws_sqs_wait_time_seconds,
        :visibilitiy_timeout => @aws_sqs_visibilitiy_timeout
      })
      $log.debug "Polling finished"
      if(notificationRaws && !notificationRaws.instance_of?(Array))
        notificationRaws = [notificationRaws]
      end
      if notificationRaws && notificationRaws.size != 0
        $log.debug "Received #{notificationRaws.size} messages"
        notificationRaws.each{ |notificationRaw|
          notification = JSON.parse(notificationRaw.as_sns_message.body)
          $log.debug "Received Notification#{notification}"
          if(process(notification))
            if dry_run
              $log.info "Notification processed in dry-run mode #{notification}"
            else
              notificationRaw.delete()
              $log.debug "Deleted processed notification #{notification}"
            end
          else
            $log.error "Could not process notification, pending... #{notification}"
          end
        }
        @locker.synchronize do
          return unless @running
        end
        sleep @aws_sqs_process_interval if(@aws_sqs_process_interval > 0)
        @locker.synchronize do
          return unless @running
        end
        next
      end
      $log.debug "No messages in queue, sleep for #{@aws_sqs_monitor_interval} secs"
      @locker.synchronize do
        return unless @running
      end
      sleep @aws_sqs_monitor_interval
      @locker.synchronize do
        return unless @running
      end
    end
  rescue => e
    puts e 
  end

  def process(notification)
    if notification["type"] == "ping"
      # Ignore ping message
      return true
    end
    if notification["type"] == "out"
      # Silently ignore non matching logs
      if notification["bucketname"] != @aws_s3_bucketname
        $log.debug "Bucketname does not match. Ignoring"
        return true
      end
      if(@channelEnableRegEx)
        unless Regexp.new(@channel).match(notification["channel"])
          $log.debug "Channel RegEx does not match. Ignoring"
          return true
        end
      else
        unless @channel == notification["channel"]
          $log.debug "Channel does not match. Ignoring"
          return true
        end
      end
      tmpFile = Tempfile.new("forward-aws-")
      begin
        #Download log file to temporary file
        $log.debug "Download log object from S3 bucket #{@aws_s3_bucketname} path #{notification["path"]}"
        @bucket.objects[notification["path"]].read do |chunk|
          tmpFile.write(chunk)
        end
        tmpFile.close()
        #gunzip and decode log file
        streamUnpacker = MessagePack::Unpacker.new()
        Zlib::GzipReader.open(tmpFile) {|reader|
          streamUnpacker.feed(reader.read())
          streamUnpacker.each {|event|
            (tag, time, record) = event
            tag = ForwardAWSUtil.filtertag(tag,@add_tag_prefix,@remove_tag_prefix)
            Fluent::Engine.emit(tag,time,record)
          }
        }
        return true
      rescue => e
        if(e.message == "Access Denied")
          $log.warn "Access Denied for key #{notification["path"]}"
          # Object may have been deleted. Do not retry
          return true
        else
          $log.error e
        end
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
      $log.debug "Stopping thread"
      @running = false
    end
    if(@thread)
      @thread.run
      @thread.join
      @thread = nil
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