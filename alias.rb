require 'singleton'
require 'yaml'
module Repoto
    class Alias
        include Singleton

        def initialize
            reload
        end

        def reload
            if File.exists?("aliases.yml")
                @aliases = YAML.load_file("aliases.yml")
            else
                @aliases = {}
            end
        end

        def add nick, al
            @aliases[nick] ||= []
            @aliases[nick] << al
            @aliases[nick].uniq!
        end

        def remove nick, al
            @aliases[nick].delete(al)
        end

        def lookup al
            @aliases.each_key do |u|
                if @aliases[u].include?(al)
                    return u
                end
            end
            return al
        end

        def dump
            File.open("aliases.yml") do |f|
                f << YAML.dump(@aliases)
            end
        end
    end
end