require "unicode"
require_relative "localization"
require_relative "ircline"
require_relative "speaker"
require_relative "config"
module Repoto
    class Conv
        def self.parse line
            if !line.nil? && line.kind_of?(IRCLine) && (line.formatted_message[/^Repoto.*: /] != nil || (line.target == Config.instance.full_nick && Unicode.upcase(line.formatted_message).match(/.*MAKA.*PAKA.*/).nil? && line.formatted_message[/redmine:#[0-9]+/].nil?))
                Thread.new do
                    msg = line.formatted_message
                    msg[/^Repoto.*: /] = "" if line.formatted_message[/^Repoto.*: /] != nil
                    if matches_keyword?(msg[0..1], :hi) || matches_keyword?(msg[0..2], :hey)
                        Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("conv.hi"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    elsif includes_keyword?(msg, :name) && includes_keyword?(msg, :what) || includes_keyword?(msg, :please)
                        Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("conv.name"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    elsif matches_keyword?(msg, :ping)
                        Speaker.instance.enqueue IRCMessage.new("#{Localization.instance.q("conv.pong")}.", line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    elsif includes_keyword?(msg, :what2) && includes_keyword?(msg, :up)
                        Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("conv.whats_up"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    elsif matches_keyword?(msg[0..2], :bye)
                        Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("conv.bye"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    elsif includes_keyword?(msg, :good) && includes_keyword?(msg, :bot)
                        Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("conv.good_bot"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    elsif (includes_keyword?(msg, :bad) || includes_keyword?(msg, :moron) || includes_keyword?(msg, :useless)) && includes_keyword?(msg, :bot)
                        Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("conv.bad_bot"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    elsif matches_keyword?(msg, :wat)
                        Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("conv.wat"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    elsif includes_keyword?(msg, :are) && includes_keyword?(msg, :you) && includes_keyword?(msg, :ok)
                        Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("conv.are_you_ok"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    elsif includes_keyword?(msg, :prefix)
                        Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("conv.prefix") + " " + Config.instance.prefix, line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    elsif (includes_keyword?(msg, :cookie) || includes_keyword?(msg, :cookie2)) && includes_keyword?(msg, :want)
                        Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("conv.cookie"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    else
                        if Random.rand(3) != 2
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