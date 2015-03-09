module Repoto
    class IRCLine
        def initialize line
            line.force_encoding('utf-8')
            @broken_line = line.split(" ")
        end

        def broken_line
            @broken_line
        end

        def broken_line= val
            @broken_line = val
        end

        def type
            if @broken_line[0][0] == ':' && @broken_line[1] == "001"
                return :firstline
            end
            if @broken_line[0] == "PING"
                return :ping
            end
            if @broken_line[0] == "ERROR"
                return :error
            end
            if @broken_line[0][0] == ":"
                if @broken_line[1] == "CAP"
                    return :cap
                elsif @broken_line[1] == "JOIN"
                    return :join
                elsif @broken_line[1] == "PART"
                    return :part
                elsif @broken_line[1] == "QUIT"
                    return :quit
                elsif @broken_line[1] == "KICK"
                    return :kick
                elsif @broken_line[1] == "PRIVMSG"
                    return :privmsg
                elsif @broken_line[1] == "NOTICE"
                    return :notice
                elsif @broken_line[1] == "401" || @broken_line[1] == "433"
                    return :ncerror
                else
                    return :notsupported
                end
            end
            return :notsupported
        end

        def usernick
            if [:cap, :join, :part, :quit, :kick, :privmsg].include?(type)
                ret = ""
                @broken_line[0].chars.each do |c|
                    if c != ":"
                        if c == "!"
                            break
                        else
                            ret += c
                        end
                    end
                end
                ret
            else
                nil
            end
        end

        def target
            return @broken_line[3] if type == :kick
            return @broken_line[2] if type == :privmsg
            nil
        end

        def message
            return @broken_line[3..-1].join(" ") if type == :privmsg
            nil
        end
    end
end