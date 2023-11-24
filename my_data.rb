class MyData
  def self.define(*keys)
    data_klass = Class.new
    data_klass.class_eval do
      def initialize(**args)
        self
        pp args
      end
      keys.each do |k|
        define_method(k) do
          self.instance_variable_get(k)
        end
      end
    end
    data_klass
  end
end
