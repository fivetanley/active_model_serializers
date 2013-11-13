require 'active_model/serializable'

module ActiveModel
  # DefaultSerializer
  #
  # Provides a constant interface for all items
  class DefaultSerializer
    include ActiveModel::Serializable

    attr_reader :object

    def initialize(object, options=nil)
      @object = object
    end

    def as_json(options={})
      return nil if @object.nil?
      if @object.is_a?(Struct)
        Hash[@object.members.zip(@object.values)]
      else
        @object.as_json
      end
    end
    alias serializable_hash as_json
    alias serializable_object as_json
  end
end
