module ActiveModel
  # DefaultSerializer
  #
  # Provides a constant interface for all items
  class DefaultSerializer
    attr_reader :object

    def initialize(object, options=nil)
      @object = object
    end

    def serializable_hash(*)
      return nil if @object.nil?
      if @object.is_a?(Struct)
        Hash[@object.members.zip(@object.values)]
      else
        @object.as_json
      end
    end
    alias serializable_object serializable_hash
  end
end
