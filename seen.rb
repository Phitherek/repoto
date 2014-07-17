module Repoto
    class Seen
        def initialize
            @seendata = {}
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
    end
end
