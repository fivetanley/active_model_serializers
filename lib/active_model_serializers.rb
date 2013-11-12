require 'active_support'
require 'active_model/serializer'
require 'active_model/serializer_support'
require 'active_model/serializer/version'
require 'active_model/serializer/railtie' if defined?(Rails) && defined?(Rails::Railtie)


module ActiveSupport
  module Inflector
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
  end
end
begin
  require 'action_controller'
  require 'action_controller/serialization'

  ActiveSupport.on_load(:action_controller) do
    include ::ActionController::Serialization
  end
rescue LoadError
  # rails not installed, continuing
end
