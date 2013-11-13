require 'active_record'
require 'active_model/array_serializer'
require 'active_model/serializable'
require 'active_model/serializer/associations'
require 'active_model/serializer/config'

require 'thread'

module ActiveRecord
  class Base
    alias read_attribute_for_serialization send
  end
end

module ActiveModel
  class Serializer
    include Serializable
    extend ActiveSupport::Inflector

    @mutex = Mutex.new

    class << self
      def inherited(base)
        base._attributes = []
        base._associations = {}
      end
      def const_regexp(camel_cased_word) #:nodoc:
        parts = camel_cased_word.split("::")
        last  = parts.pop

        parts.reverse.inject(last) do |acc, part|
          part.empty? ? acc : "#{part}(::#{acc})?"
        end
      end
      def safe_constantize(camel_cased_word)
        begin
          constantize(camel_cased_word)
        rescue NameError => e
          raise unless e.message =~ /(uninitialized constant|wrong constant name) #{const_regexp(camel_cased_word)}$/ ||
            e.name.to_s == camel_cased_word.to_s
        rescue ArgumentError => e
          raise unless e.message =~ /not missing constant #{const_regexp(camel_cased_word)}\!$/
        end
      end

      def setup
        @mutex.synchronize do
          yield CONFIG
        end
      end

      def embed(type, options={})
        CONFIG.embed = type
        CONFIG.embed_in_root = true if options[:embed_in_root] || options[:include]
        ActiveSupport::Deprecation.warn <<-WARN
** Notice: embed is deprecated. **
The use of .embed method on a Serializer will be soon removed, as this should have a global scope and not a class scope.
Please use the global .setup method instead:
ActiveModel::Serializer.setup do |config|
  config.embed = :#{type}
  config.embed_in_root = #{CONFIG.embed_in_root || false}
end
        WARN
      end

      if RUBY_VERSION >= '2.0'
        def serializer_for(resource)
          if resource.respond_to?(:to_ary)
            ArraySerializer
          else
            begin
              Object.const_get "#{resource.class.name}Serializer"
            rescue NameError
              nil
            end
          end
        end
      else
        def serializer_for(resource)
          if resource.respond_to?(:to_ary)
            ArraySerializer
          else
            safe_constantize "#{resource.class.name}Serializer"
          end
        end
      end

      attr_accessor :_root, :_attributes, :_associations
      alias root  _root=
      alias root= _root=

      def root_name
        name.demodulize.underscore.sub(/_serializer$/, '') if name
      end

      def attributes(*attrs)
        @_attributes.concat attrs

        attrs.each do |attr|
          define_method attr do
            object.read_attribute_for_serialization attr
          end unless method_defined?(attr)
        end
      end

      def has_one(*attrs)
        associate(Association::HasOne, *attrs)
      end

      def has_many(*attrs)
        associate(Association::HasMany, *attrs)
      end

      private

      def associate(klass, *attrs)
        options = attrs.extract_options!

        attrs.each do |attr|
          define_method attr do
            object.send attr
          end unless method_defined?(attr)

          @_associations[attr] = klass.new(attr, options)
        end
      end
    end

    def initialize(object, options={})
      @object   = object
      @scope    = options[:scope]
      @root     = options.fetch(:root, self.class._root)
      @meta_key = options[:meta_key] || :meta
      @meta     = options[@meta_key]
    end
    attr_accessor :object, :scope, :meta_key, :meta, :root

    def json_key
      if root == true || root.nil?
        self.class.root_name
      else
        root
      end
    end

    def attributes
      filter(self.class._attributes.dup).each_with_object({}) do |name, hash|
        hash[name] = send(name)
      end
    end

    def associations
      associations = self.class._associations
      included_associations = filter(associations.keys)
      associations.each_with_object({}) do |(name, association), hash|
        if included_associations.include? name
          if association.embed_ids?
            hash[association.key] = serialize_ids association
          elsif association.embed_objects?
            associated_data = send(association.name)
            hash[association.embedded_key] = serialize(association, associated_data)
          end
        end
      end
    end

    def filter(keys)
      keys
    end

    def embedded_in_root_associations
      associations = self.class._associations
      included_associations = filter(associations.keys)
      associations.each_with_object({}) do |(name, association), hash|
        if included_associations.include? name
          if association.embed_in_root?
            associated_data = Array(send(association.name))
            hash[association.root_key] = serialize(association, associated_data)
          end
        end
      end
    end

    def serialize(association, object)
      association.build_serializer(object, scope: scope).serializable_object
    end

    def serialize_ids(association)
      associated_data = send(association.name)
      if associated_data.respond_to?(:to_ary)
        associated_data.map { |elem| elem.read_attribute_for_serialization(association.embed_key) }
      else
        associated_data.read_attribute_for_serialization(association.embed_key) if associated_data
      end
    end

    def serializable_hash(options={})
      return nil if object.nil?
      hash = attributes
      hash.merge! associations
    end
    alias_method :serializable_object, :serializable_hash
  end

end
