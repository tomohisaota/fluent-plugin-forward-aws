require 'helper'

class ForwardAWSInputTest < Test::Unit::TestCase
  DUMMYCONFIG = %[
    aws_access_key_id     TEST_AWS_ACCESS_KEY_ID
    aws_secret_access_key TEST_AWS_SECRET_ACCESS_KEY

    aws_s3_endpoint       TEST_AWS_S3_ENDPOINT
    aws_s3_bucketname     TEST_AWS_S3_BUCKETNAME
    aws_s3_skiptest       true
    
    aws_sqs_endpoint      TEST_AWS_SQS_ENDPOINT
    aws_sqs_queue_url     TEST_AWS_SQS_QUEUE_URL
    aws_sqs_skiptest      true
    
    start_thread          false
  ]

  def setup
    Fluent::Test.setup
    begin
      require 'yaml'
      @AWSTESTCONFIG = YAML.load_file(File.expand_path('../../awsconfig.yml', __FILE__))

      @CONFIG = %[
        aws_access_key_id     #{@AWSTESTCONFIG["aws_access_key_id"]}
        aws_secret_access_key #{@AWSTESTCONFIG["aws_secret_access_key"]}

        aws_s3_endpoint       #{@AWSTESTCONFIG["aws_s3_endpoint"]}
        aws_s3_bucketname     #{@AWSTESTCONFIG["aws_s3_bucketname"]}
        aws_s3_skiptest       true

        aws_sqs_endpoint      #{@AWSTESTCONFIG["aws_sqs_endpoint"]}
        aws_sqs_queue_url     #{@AWSTESTCONFIG["aws_sqs_queue_url"]}
        aws_sqs_skiptest      true

        start_thread          false
      ]
    rescue => e
    end
  end
  
  def create_driver(conf)
    Fluent::Test::InputTestDriver.new(Fluent::ForwardAWSInput).configure(conf)
  end
  
  def test_configure
    d = create_driver(DUMMYCONFIG)
    ### check configurations
    assert_equal( 'TEST_AWS_ACCESS_KEY_ID',     d.instance.aws_access_key_id)
    assert_equal( 'TEST_AWS_SECRET_ACCESS_KEY', d.instance.aws_secret_access_key)
    
    assert_equal( 'TEST_AWS_S3_ENDPOINT',     d.instance.aws_s3_endpoint)
    assert_equal( 'TEST_AWS_S3_BUCKETNAME',     d.instance.aws_s3_bucketname)

    assert_equal( 'TEST_AWS_SQS_ENDPOINT',     d.instance.aws_sqs_endpoint)
    assert_equal( 'TEST_AWS_SQS_QUEUE_URL',     d.instance.aws_sqs_queue_url)
  end
  
  def test_check_aws_s3
    unless(@CONFIG)
      # Skip Test
      return
    end
    create_driver(@CONFIG + "aws_s3_skiptest false").run()
  end

  def test_check_aws_sqs
    unless(@CONFIG)
      # Skip Test
      return
    end
    create_driver(@CONFIG + "aws_sqs_skiptest false").run()
  end
end