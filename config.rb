require 'yaml'
require 'singleton'

module Repoto
    class Config
        include Singleton
        def initialize
             if File.exists?("config.yml")
                @config = YAML.load_file("config.yml")
            else
                raise "Could not read config!"
            end
        end

        def respond_to?(sym, include_private = false)
            handle?(sym)  || super(sym, include_private)
        end

        def method_missing(sym, *args, &block)
            return @config[sym] if handle?(sym)
            super(sym, *args, &block)
        end

        def formatted_channel
            "#" + self.channel
        end

        def nick
            "Repoto"
        end

        def version
            "3.0.6"
        end

        def creator
            "Phitherek_"
        end

        def port
            @config[:port].to_i
        end

        def reload
            if File.exists?("config.yml")
                @config = YAML.load_file("config.yml")
            else
                raise "Could not read config!"
            end
        end

        def full_nick
            "#{nick}#{!suffix.nil? ? "|#{suffix}" : ""}"
        end

        private

        def handle?(sym)
            @config[sym] != nil
        end
    end
end
