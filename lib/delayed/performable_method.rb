module Delayed
  class PerformableMethod < Struct.new(:object, :method, :args)
    CLASS_STRING_FORMAT           = /^CLASS\:([A-Z][\w\:]+)$/
    ACTIVERECORD_STRING_FORMAT    = /^ACTIVERECORD\:([A-Z][\w\:]+)\:(\d+)$/
    ACTIVERESOURCE_STRING_FORMAT  = /^ACTIVERESOURCE\:([A-Z][\w\:]+)\:(\d+)$/

    def initialize(object, method, args)
      raise NoMethodError, "undefined method `#{method}' for #{self.inspect}" unless object.respond_to?(method)

      self.object = dump(object)
      self.args   = args.map { |a| dump(a) }
      self.method = method.to_sym
    end
    
    def display_name  
      case self.object
      when CLASS_STRING_FORMAT          then "#{$1}.#{method}"
      when ACTIVERECORD_STRING_FORMAT   then "#{$1}##{method}"
      when ACTIVERESOURCE_STRING_FORMAT then "#{$1}##{method}"
      else "Unknown##{method}"
      end      
    end    

    def perform
      load(object).send(method, *args.map{|a| load(a)})
    #ActiveResource::ResourceNotFound
    rescue ActiveRecord::RecordNotFound
      # We cannot do anything about objects which were deleted in the meantime
      true
    end

    private

    def load(arg)
      case arg
      when CLASS_STRING_FORMAT          then $1.constantize
      when ACTIVERECORD_STRING_FORMAT   then $1.constantize.find($2)
      when ACTIVERESOURCE_STRING_FORMAT then $1.constantize.find($2)
      else arg
      end
    end

    def dump(arg)
      case arg
      when Class                then class_to_string(arg)
      when ActiveRecord::Base   then active_record_to_string(arg)
      when ActiveResource::Base then active_resource_to_string(arg)
      else arg
      end
    end

    def active_resource_to_string(obj)
      "ACTIVERESOURCE:#{obj.class}:#{obj.id}"
    end

    def active_record_to_string(obj)
      "ACTIVERECORD:#{obj.class}:#{obj.id}"
    end

    def class_to_string(obj)
      "CLASS:#{obj.name}"
    end
  end
end