require_relative 'servicesauth'
module Repoto
    class IRCLine
        def initialize line
            if !line.nil?
                line.force_encoding('utf-8')
                @broken_line = line.split(" ")
            else
                @broken_line = ""
            end
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
                    if @broken_line[4] == "ACC"
                        return :acc
                    else
                        return :notice
                    end
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
            return @broken_line[3..-1].join(" ")[1..-1] if type == :privmsg
            nil
        end

        def formatted_message
            if !message.nil?
                if ServicesAuth.instance.method == :imsg
                    return message[1..-1]
                else
                    return message
                end
            end
            nil
        end

        def broken_formatted_message
            if !formatted_message.nil?
                return formatted_message.split(" ")
            end
            nil
        end
    end
end