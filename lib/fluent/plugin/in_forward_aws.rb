class Fluent::ForwardAWSInput < Fluent::Input
  Fluent::Plugin.register_input('forward-aws', self)

  # config_param :hoge, :string, :default => 'hoge'

  def configure(conf)
    super
    # @path = conf['path']
  end

  def start
    super
    # init
  end

  def shutdown
    super
    # destroy
  end
end