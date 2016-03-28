module Dokumi
  module Support
    module XML
      def self.read_xml_tag(text)
        h = {}
        s = StringScanner.new(text)
        return nil unless s.scan(/\s*<([a-zA-Z][a-zA-Z0-9]*)/)
        tag_type = s[1].to_sym
        while s.scan(/\s*([a-zA-Z][a-zA-Z0-9]*)=(?:["'])([^"']+)(["'])\s*/)
          name, value = s[1], s[2]
          h[name.to_sym] = value
        end
        return tag_type, h
      end
    end
  end
end
