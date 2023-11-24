class MyData
  def self.define(*keys)
    self.validate_keys!(keys)

    data_klass = Class.new
    data_klass.class_eval do
      @@keys = keys
      def initialize(**args) ## TODO ここarray, hash両方うける
        if args.is_a?(Array)
          if keys.size != args.size
            raise NoMethodError "keys.size -> #{keys.size}, but args.size -> #{args.size}"
          end
        end
        @hashmap = args || {}
      end

      @@keys.each do |k|
        define_method(k) do
          @hashmap[k]
        end
      end

      def self.members
        @@keys
      end
    end
    data_klass
  end

  private

    def self.validate_keys!(keys)
      keys.each do |k|
        unless !k.is_a?(Symbol) || !k.is_a?(String)
          raise TypeError.new "Definition key should be Symbol or String (given: #{k.inspect})"
        end
      end
    end
end
