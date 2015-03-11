require 'unicode'
require_relative 'ircline'
require_relative 'config'
require_relative 'dynconfig'
require_relative 'speaker'
require_relative 'ircmessage'
require_relative 'localization'
require_relative 'servicesauth'
require_relative 'ping'
require_relative 'seen'
require_relative 'memo'
require_relative 'reminder'
require_relative 'ignore'
require_relative 'alias'
module Repoto
    class Functions
        def self.parse line
            if !line.nil? && line.kind_of?(IRCLine) && line.formatted_message[0] == Config.instance.prefix && line.formatted_message[1] != Config.instance.prefix && line.formatted_message[1] != "_" && line.formatted_message[1] != " " && line.formatted_message[1] != "\n" && line.formatted_message[1] != nil
                Thread.new do
                    if line.target == Config.instance.formatted_channel && [:version, :creator, :operators, :exit, :poke, :kick, :ping, :addop, :dumpdyn, :lc, :ac, :rc, :c, :cu, :cd, :cr, :issues, :enablehskrk, :disablehskrk, :whois, :temp, :graphite, :light, :locales, :locale, :seen, :memo, :id, :remind, :ignore, :save, :restart, :help, :alias].include?(line.broken_formatted_message[0][1..-1].to_sym)
                        self.send(line.broken_formatted_message[0][1..-1], line)
                    elsif [:version, :creator, :operators, :exit, :addop, :dumpdyn, :lc, :ac, :rc, :c, :cu, :cd, :cr, :issues, :enablehskrk, :disablehskrk, :whois, :temp, :graphite, :light, :locales, :locale, :seen, :memo, :id, :remind, :ignore, :restart, :help, :alias].include?(line.broken_formatted_message[0][1..-1].to_sym)
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

        def self.version line
            Speaker.instance.enqueue IRCMessage.new("#{Localization.instance.q("functions.version")} #{Config.instance.version}", line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
        end

        def self.creator line
            Speaker.instance.enqueue IRCMessage.new("#{Localization.instance.q("functions.creator")} #{Config.instance.creator}", line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
        end

        def self.operators line
            Speaker.instance.enqueue IRCMessage.new("#{Localization.instance.q("functions.operators")} #{DynConfig.instance.operators.join(" ")}", line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
        end

        def self.exit line
            if is_operator?(line.usernick)
                Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.exit.channel"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                Speaker.instance.enqueue IRCMessage.new("QUIT :#{Localization.instance.q("functions.exit.quit")}", nil, :raw)
                Microphone.instance.mute
                while !Speaker.instance.empty?
                    sleep 0.01
                end
                Speaker.instance.mute
                Ping.instance.stop
                DynConfig.instance.dump
                Seen.instance.dump
                Memo.instance.dump
                Reminder.instance.dump
                Ignore.instance.dump
                Alias.instance.dump
                Connection.instance.close
                Thread.main.exit
            else
                Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("errors.not_authorized"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
            end
        end

        def self.poke line

        end

        def  self.ping line

        end

        def self.kick line

        end

        def self.addop line

        end

        def self.dumpdyn line

        end

        def self.lc line

        end

        def self.ac line

        end

        def self.rc line

        end

        def self.c line

        end

        def self.cu line

        end

        def self.cd line

        end

        def self.cr line

        end

        def self.issues line

        end

        def self.enablehskrk line

        end

        def self.disablehskrk line

        end

        def self.whois line

        end

        def self.temp line

        end

        def self.graphite line

        end

        def self.light line

        end

        def self.locales line

        end

        def self.locale line

        end

        def self.seen line

        end

        def self.memo line

        end

        def self.id line

        end

        def self.remind line

        end

        def self.ignore line

        end

        def self.save line

        end

        def self.restart line

        end

        def self.help line

        end

        def self.alias line

        end

        private

        def self.is_operator?(usernick)
            !usernick.nil? && DynConfig.instance.operators.include?(usernick) && ServicesAuth.instance.status(usernick) == :logged_in
        end
    end
end