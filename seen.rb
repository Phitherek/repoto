require 'yaml'

module Repoto
    class Seen
        def initialize
            if File.exists?("seendata.yml")
                @seendata = YAML.load_file("seendata.yml")
            else
                @seendata = {}
            end
        end
        
        def find nick
            if !@seendata[nick.to_s]
                nil
            else
                if @seendata[nick.to_s][:type] == :join
                    :now
                else
                    @seendata[nick.to_s][:time]
                end
            end
        end

        def update nick, type
            @seendata[nick.to_s] ||= {}
            @seendata[nick.to_s][:time] = Time.now.to_s
            @seendata[nick.to_s][:type] = type.to_sym
        end
        
        def dump
            @seendata.keys.each do |nick|
                if @seendata[nick][:type] == :join
                    @seendata[nick][:time] = Time.now.to_s
                    @seendata[nick][:type] = :part
                end
            end
                    
            File.open("seendata.yml", "w") do |f|
                f << YAML.dump(@seendata)
            end
        end
    end
end
