require 'helper'

class ForwardAWSUtilTest < Test::Unit::TestCase
  require_relative "../../lib/fluent/plugin/forward_aws_util"
  include ForwardAWSUtil
  
  def test_filtertag
    assert_equal('aaa',ForwardAWSUtil.filtertag("aaa"))
    assert_equal('aaa.bbb',ForwardAWSUtil.filtertag("aaa.bbb"))
    assert_equal('aaa.bbb.ccc',ForwardAWSUtil.filtertag("aaa.bbb.ccc"))

    # Add prefix
    assert_equal('ddd.aaa',ForwardAWSUtil.filtertag("aaa","ddd"))
    assert_equal('ddd.aaa.bbb',ForwardAWSUtil.filtertag("aaa.bbb","ddd"))
    assert_equal('ddd.aaa.bbb.ccc',ForwardAWSUtil.filtertag("aaa.bbb.ccc","ddd"))

    # Remove prefix
    assert_equal('',ForwardAWSUtil.filtertag("aaa",nil,"aaa"))
    assert_equal('bbb',ForwardAWSUtil.filtertag("aaa.bbb",nil,"aaa"))
    assert_equal('bbb.ccc',ForwardAWSUtil.filtertag("aaa.bbb.ccc",nil,"aaa"))
    
    # Add and remove
    assert_equal('ccc.bbb',ForwardAWSUtil.filtertag("aaa.bbb","ccc","aaa"))

    # Corner cases
    # Do not remove tag in middle
    assert_equal('aaa.bbb.ccc',ForwardAWSUtil.filtertag("aaa.bbb.ccc",nil,"bbb"))
    # Do not remove incomplete tag
    assert_equal('aaaa.bbb',ForwardAWSUtil.filtertag("aaaa.bbb",nil,"aaa"))
    # Remove tag does not affect newly added tag
    assert_equal('ccc.ddd.aaa.bbb',ForwardAWSUtil.filtertag("aaa.bbb","ccc.ddd","ccc"))
    assert_equal('ccc.ddd.bbb',ForwardAWSUtil.filtertag("aaa.bbb","ccc.ddd","aaa"))
    
  end
end