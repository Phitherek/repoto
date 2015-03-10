require_relative 'ircmessage'
require_relative 'ircline'
require_relative 'config'
module Repoto
    class IRCTranslator
        def self.to_irc msg
            if !msg.kind_of?(IRCMessage)
                text = msg
                msg = IRCMessage.new text
            end
            translated = ""
            translated += "PRIVMSG "
            if msg.type == :privmsg
                translated += msg.target
                translated += " :"
                if msg.action?
                    translated += "\001ACTION "
                    translated += msg.content
                    translated += "\001"
                else
                    translated += msg.content
                end
            elsif msg.type == :channel
                translated += Config.instance.formatted_channel
                translated += " :"
                if msg.action?
                    translated += "\001ACTION "
                    translated += msg.content
                    translated += "\001"
                else
                    if !msg.target.nil?
                        translated += msg.target
                        translated += ": "
                    end
                    translated += msg.content
                end
            elsif msg.type == :raw
                msg.content
            end
        end

        def self.from_irc line
            IRCLine.new line
        end
    end
end