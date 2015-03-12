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
            if @dynconfig[:hskrk].nil?
                @dynconfig[:hskrk] = "off"
            end
        end

        def reload
            if File.exists?("dynconfig.yml")
                @dynconfig = YAML.load_file("dynconfig.yml")
            else
                @dynconfig = {}
            end
        end

        def dump
            File.open("dynconfig.yml", "w") do |f|
                f << YAML.dump(@dynconfig)
            end
        end

        def respond_to?(sym, include_private = false)
            handle?(sym)  || super(sym, include_private)
        end

        def method_missing(sym, *args, &block)
            if sym =~ /^(\w+)=$/
                @dynconfig["#{$1}".to_sym] = args[0]
            else
                return @dynconfig[sym] if handle?(sym)
                super(sym, *args, &block)
            end
        end

        private

        def handle?(sym)
            @dynconfig[sym] != nil
        end
    end
end
