module Dokumi
  module Support
    def self.validate_hash(hash, validation)
      validation = validation.dup
      if (must_have_only = validation.delete(:requires_only))
        validate_hash hash, requires: must_have_only, only: must_have_only
      else
        if (requires = validation.delete(:requires))
          keys_required = [ requires ].flatten
          keys_required.each do |key|
            raise "#{key.inspect} key required" unless hash.has_key?(key)
          end
        end
        if (can_also_have = validation.delete(:can_also_have)) or (only = validation.delete(:only))
          if can_also_have
            raise ":can_also_have must be used with :requires" unless requires
            keys_allowed = [ can_also_have, requires ].flatten
          else
            keys_allowed = [ only ].flatten
          end
          hash.keys.each do |key|
            raise "#{key.inspect} key not allowed" unless keys_allowed.include?(key)
          end
        end
      end
      raise "unknown types of validation #{validation.keys.inspect}" unless validation.empty?
    end

    def self.extract_options!(args, validation = {})
      if !args.empty? and args.last.is_a?(Hash)
        options = args.pop
      else
        options = {}
      end
      validate_hash(options, validation) unless validation.empty?
      options
    end

    def self.symbolize_keys(to_symbolize)
      h = {}
      to_symbolize.each do |k, v|
        h[k.to_sym] = v
      end
      h
    end

    def self.update_hash!(hash, path, *args, &block)
      if args.last.is_a?(Hash)
        opts = args.pop
      else
        opts = {}
      end
      if args.length == 0
        raise "a block (or value) is required" unless block
      elsif args.length == 1
        raise "no block allowed is replacement value given" if block
        value = args.pop
        block = Proc.new { value }
      else
        raise "invalid arguments"
      end

      current = hash
      path_left = path.split("/")
      loop do
        subpath = path_left.shift
        if subpath == "*"
          return unless current

          if current.is_a?(Hash)
            key_enumerator = current.each_key
          elsif current.is_a?(Array)
            key_enumerator = current.each_index
          else
            raise "the * in #{path} must point to an Array or Hash, and #{current.inspect} is neither of those"
          end

          if path_left.empty?
            key_enumerator.each do |key|
              current[key] = block.call(current[key])
            end
          else
            key_enumerator.each do |key|
              update_hash! current[key], path_left.join("/"), opts, &block
            end
          end
          return
        end

        return if opts[:optional] and !current.has_key?(subpath)
        if path_left.empty?
          current[subpath] = block.call(current[subpath])
          return hash
        end
        current = current[subpath]
      end
    end

    def self.make_pathname(path)
      if path == nil
        nil
      elsif path.is_a?(Pathname)
        path
      else
        Pathname.new(path)
      end
    end

    def self.camel_case(string)
      string.to_s.gsub(/(^[a-z]|_[a-z])/) {|character| character[-1].upcase }
    end
  end
end
