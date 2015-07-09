module Dokumi
  module Support
    class FrozenStruct
      FORBIDDEN_FIELD_NAMES = [:fields, :to_h, :initialize, :dup, :clone, :freeze, :frozen?]
      def self.make_class(*fields, &block)
        field_names = fields.flatten.map {|field| field.to_sym }.freeze
        field_names.each {|field| raise "invalid field name #{field}" if FORBIDDEN_FIELD_NAMES.include?(field) }
        klass = Class.new(self) do
          define_singleton_method(:fields) { field_names }
          fields.each do |field|
            define_method(field) { @values[field] }
          end
        end
        klass.class_eval(&block) if block
        klass
      end

      def initialize(h)
        @values = {}
        h.each do |field, value|
          field = field.to_sym
          raise "invalid field #{field}" unless self.class.fields.include?(field)
          @values[field] = value.is_a?(Symbol) ? value : value.dup.freeze
        end
        @values.freeze
      end

      def to_h
        @values.dup
      end

      [:dup, :clone, :freeze].each do |name|
        define_method(name) { self }
      end

      def frozen?
        true
      end

      def self.merge(from, h = {})
        new(from.to_h.merge(h))
      end
    end
  end
end
