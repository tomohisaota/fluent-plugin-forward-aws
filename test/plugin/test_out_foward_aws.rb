require 'helper'
require 'yaml'

class ForwardAWSOutputTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
  end

  AWSTESTCONFIG = YAML.load_file(File.expand_path('../../awsconfig.yml', __FILE__))

  CONFIG = %[
    aws_access_key_id     #{AWSTESTCONFIG["aws_access_key_id"]}
    aws_secret_access_key #{AWSTESTCONFIG["aws_secret_access_key"]}

    aws_s3_endpoint       #{AWSTESTCONFIG["aws_s3_endpoint"]}
    aws_s3_bucketname     #{AWSTESTCONFIG["aws_s3_bucketname"]}
    aws_s3_skiptest       true

    aws_sns_endpoint      #{AWSTESTCONFIG["aws_sns_endpoint"]}
    aws_sns_topic_arn     #{AWSTESTCONFIG["aws_sns_topic_arn"]}
    aws_sns_skiptest      true
    
    buffer_type memory
  ]

  def create_driver(conf = CONFIG, tag='test')
    Fluent::Test::BufferedOutputTestDriver.new(Fluent::ForwardAWSOutput) do
      def write(chunk)
        chunk.read
      end
    end.configure(conf)
  end

  def test_configure
    d = create_driver %[
      aws_access_key_id     TEST_AWS_ACCESS_KEY_ID
      aws_secret_access_key TEST_AWS_SECRET_ACCESS_KEY

      aws_s3_endpoint       TEST_AWS_S3_ENDPOINT
      aws_s3_bucketname     TEST_AWS_S3_BUCKETNAME
      aws_s3_skiptest       true
      
      aws_sns_endpoint      TEST_AWS_SNS_ENDPOINT
      aws_sns_topic_arn     TEST_AWS_SNS_TOPIC_ARN
      aws_sns_skiptest      true
      
      buffer_type memory
    ]
    ### check configurations
    assert_equal( 'TEST_AWS_ACCESS_KEY_ID',     d.instance.aws_access_key_id)
    assert_equal( 'TEST_AWS_SECRET_ACCESS_KEY', d.instance.aws_secret_access_key)
    
    assert_equal( 'TEST_AWS_S3_ENDPOINT',     d.instance.aws_s3_endpoint)
    assert_equal( 'TEST_AWS_S3_BUCKETNAME',     d.instance.aws_s3_bucketname)

    assert_equal( 'TEST_AWS_SNS_ENDPOINT',     d.instance.aws_sns_endpoint)
    assert_equal( 'TEST_AWS_SNS_TOPIC_ARN',     d.instance.aws_sns_topic_arn)
  end

  def test_format
    d = create_driver()

    time = Time.parse("2011-01-02 13:14:15 UTC").to_i
    d.emit({"a"=>1}, time)
    d.emit({"a"=>2}, time)

    d.expect_format ["test",time,{"a"=>1}].to_msgpack
    d.expect_format ["test",time,{"a"=>2}].to_msgpack
    d.run
  end

  def test_write
    d = create_driver()

    # time = Time.parse("2011-01-02 13:14:15 UTC").to_i
    # d.emit({"a"=>1}, time)
    # d.emit({"a"=>2}, time)

    # ### FileOutput#write returns path
    # path = d.run
    # expect_path = "#{TMP_DIR}/out_file_test._0.log.gz"
    # assert_equal expect_path, path
  end
  
  def test_check_aws_s3
    create_driver(CONFIG + "aws_s3_skiptest false").run()
  end

  def test_check_aws_sns
    create_driver(CONFIG + "aws_sns_skiptest false").run()
  end
end