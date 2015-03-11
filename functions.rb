require 'unicode'
require_relative 'ircline'
require_relative 'config'
require_relative 'dynconfig'
require_relative 'speaker'
require_relative 'ircmessage'
require_relative 'localization'
module Repoto
    class Functions
        def self.parse line
            if !line.nil? && line.kind_of?(IRCLine) && line.formatted_message[0] == Config.instance.prefix && line.formatted_message[1] != Config.instance.prefix && line.formatted_message[1] != "_" && line.formatted_message[1] != " " && line.formatted_message[1] != "\n" && line.formatted_message[1] != nil
                Thread.new do
                    if line.target == Config.instance.formatted_channel && [].include?(line.broken_formatted_message[0][1..-1].to_sym)
                        self.send(line.broken_formatted_message[0][1..-1], line)
                    elsif [].include?(line.broken_formatted_message[0][1..-1].to_sym)
                        self.send(line.broken_formatted_message[0][1..-1], line)
                    else
                        Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("errors.no_command"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    end
                end
                true
            else
                false
            end
        end
    end
end