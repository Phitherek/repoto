require 'yaml'

module Repoto
    class Ignore
        def initialize
            if File.exists?("ignores.yml")
                @ignores = YAML.load_file("ignores.yml")
            else
                @ignores = []
            end
            if !@ignores
                @ignores = []
            end
        end

        def add nick
            ignore = true
            @ignores.each do |i|
                if i == nick
                    ignore = false
                end
            end
            if ignore
                @ignores << nick
            end
        end

        def list
            @ignores
        end

        def has? nick
            @ignores.each do |i|
                if i == nick
                    return true
                end
            end
            return false
        end

        def remove nick
            @ignores.delete(nick)
        end

        def dump
            File.open("ignores.yml", "w") do |f|
                f << YAML.dump(@ignores)
            end
        end
    end
end
