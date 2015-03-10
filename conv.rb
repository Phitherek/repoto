module Repoto
    class Conv
        def self.parse line
            if !line.nil? && line.kind_of?(IRCLine) && line.formatted_message[/^Repoto.*: /] != nil
                Thread.new do
                    msg = line.formatted_message

                end
                true
            else
                false
            end
        end
    end
end