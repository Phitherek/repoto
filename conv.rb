require "unicode"
require_relative "localization"
require_relative "ircline"
require_relative "speaker"
require_relative "config"
module Repoto
    class Conv
        def self.parse line
            if !line.nil? && line.kind_of?(IRCLine) && line.formatted_message[/^Repoto.*: /] != nil
                Thread.new do
                    msg = line.formatted_message
                    msg[/^Repoto.*: /] = ""
                    if matches_keyword?(msg[0..1], :hi) || matches_keyword?(msg[0..2], :hey)
                        Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("conv.hi"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    else
                        if Random.rand(2) == 1
                            Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("conv.generic"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                        end
                    end
                end
                true
            else
                false
            end
        end

        def self.includes_keyword? content, key
            Unicode.upcase(content).include?(Unicode.upcase(Localization.instance.q("conv.keywords.#{key.to_s}")))
        end

        def self.matches_keyword? content, key
            Unicode.upcase(content) == Unicode.upcase(Localization.instance.q("conv.keywords.#{key.to_s}"))
        end
    end
end