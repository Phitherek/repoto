module Repoto
    class Extras
        def self.parse line
            if !line.nil? && line.kind_of?(IRCLine)
                Thread.new do
                    if Unicode.upcase(line.formatted_message).match(/.*MAKA.?PAKA.*/) != nil

                    end
                end
            end
        end
    end
end