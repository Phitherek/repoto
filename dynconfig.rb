require 'yaml'
require 'singleton'

module Repoto
    class DynConfig
        include Singleton
        
        def initialize
             if File.exists?("dynconfig.yml")
                @dynconfig = YAML.load_file("dynconfig.yml")
            else
                @dynconfig = {}
            end
        end
        
        def respond_to?(sym, include_private = false)
            handle?(sym)  || super(sym, include_private)
        end
        
        def method_missing(sym, *args, &block)
            return @config[sym] if handle?(sym)
            super(sym, *args, &block)
        end
        
        private
        
        def handle?(sym)
            @config[sym] != nil
        end
    end
end
