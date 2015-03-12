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
require_relative 'github'
module Repoto
    class Functions
        if Config.instance.github_enabled
            @@github = Github.new(Config.instance.github_access_key)
        end
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
            if line.broken_formatted_message[1].nil?
                Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.poke.question"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
            else
                Speaker.instance.enqueue IRCMessage.new("#{Localization.instance.q("functions.poke.msg1")} #{line.broken_formatted_message[1]} #{Localization.instance.q("functions.poke.msg2")} #{line.usernick}#{Localization.instance.q("functions.poke.msg3")}", nil, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg, true)
            end
        end

        def  self.ping line
            if line.broken_formatted_message[1].nil?
                 Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.ping.question"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
            else
                 Speaker.instance.enqueue IRCMessage.new("#{Localization.instance.q("functions.ping.msg")} #{line.usernick}", line.broken_formatted_message[1], (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
            end
        end

        def self.kick line
            if line.broken_formatted_message[1].nil?
                Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.kick.question"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
            else
                Speaker.instance.enqueue IRCMessage.new("#{Localization.instance.q("functions.kick.msg1")} #{line.broken_formatted_message[1]} #{Localization.instance.q("functions.kick.msg2")} #{line.usernick}#{Localization.instance.q("functions.kick.msg3")}", nil, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg, true)
            end
        end

        def self.addop line
            if is_operator?(line.usernick)
                if !line.broken_formatted_message[1].nil?
                    DynConfig.instance.operators << line.broken_formatted_message[1]
                    Speaker.instance.enqueue IRCMessage.new("#{line.usernick} #{Localization.instance.q("functions.addop")}", line.broken_formatted_message[1], (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                else
                    Speaker.instance.enqueue IRCMessage.new("#{Localization.instance.q("usage")} #{Config.instance.prefix}addop user_nick", line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                end
            else
                Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("errors.not_authorized"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
            end
        end

        def self.dumpdyn line
            if is_operator?(line.usernick)
                DynConfig.instance.dump
                Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.dumpdyn"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
            else
                Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("errors.not_authorized"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
            end
        end

        def self.lc line
            if !DynConfig.instance.c.nil?
                Speaker.instance.enqueue IRCMessage.new("#{Localization.instance.q("functions.lc.prelist")} " + DynConfig.instance.c.keys.join(" ").to_s, line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
            else
                Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.lc.no_commands"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
            end
        end

        def self.ac line
            if !line.broken_formatted_message[1].nil? && !line.broken_formatted_message[2].nil?
                DynConfig.instance.c ||= {}
                DynConfig.instance.c[cmd[1].to_sym] = cmd[2..-1].join(" ").to_s
                Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.ac.success"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
            else
                Speaker.instance.enqueue IRCMessage.new("#{Localization.instance.q("usage")} #{Config.instance.prefix}ac #{Localization.instance.q("functions.ac.command_name")} #{Localization.instance.q("functions.ac.command_output")}", line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
            end
        end

        def self.rc line
            if !line.broken_formatted_message[1].nil?
                if !DynConfig.instance.c.nil? && !DynConfig.instance.c[cmd[1].to_sym].nil?
                    DynConfig.instance.c.delete(cmd[1].to_sym)
                    Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.rc.success"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                else
                    Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.rc.no_command"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                end
            else
                Speaker.instance.enqueue IRCMessage.new("#{Localization.instance.q("usage")} #{Config.instance.prefix}rc #{Localization.instance.q("functions.rc.command_name")}", line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
            end
        end

        def self.c line
            if !line.broken_formatted_message[1].nil?
                if !DynConfig.instance.c.nil? && !DynConfig.instance.c[line.broken_formatted_message[1].to_sym].nil?
                    Speaker.instance.enqueue IRCMessage.new(DynConfig.instance.c[line.broken_formatted_message[1].to_sym].to_s, (line.target == Config.instance.formatted_channel) ? nil : line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                else
                    Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.c.no_command"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                end
            else
                Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.c.question"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
            end
        end

        def self.cu line
            if !line.broken_formatted_message[1].nil?
                if !DynConfig.instance.c.nil? && !DynConfig.instance.c[line.broken_formatted_message[1].to_sym].nil?
                    Speaker.instance.enqueue IRCMessage.new(Unicode.upcase(DynConfig.instance.c[line.broken_formatted_message[1].to_sym].to_s), (line.target == Config.instance.formatted_channel) ? nil : line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                else
                    Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.c.no_command"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                end
            else
                Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.c.question"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
            end
        end

        def self.cd line
            if !line.broken_formatted_message[1].nil?
                if !DynConfig.instance.c.nil? && !DynConfig.instance.c[line.broken_formatted_message[1].to_sym].nil?
                    Speaker.instance.enqueue IRCMessage.new(Unicode.downcase(DynConfig.instance.c[line.broken_formatted_message[1].to_sym].to_s), (line.target == Config.instance.formatted_channel) ? nil : line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                else
                    Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.c.no_command"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                end
            else
                Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.c.question"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
            end
        end

        def self.cr line
            if !line.broken_formatted_message[1].nil?
                if !DynConfig.instance.c.nil? && !DynConfig.instance.c[line.broken_formatted_message[1].to_sym].nil?
                    if !line.broken_formatted_message[2].nil?
                        line.broken_formatted_message[2].to_i.times do
                            Speaker.instance.enqueue IRCMessage.new(DynConfig.instance.c[line.broken_formatted_message[1].to_sym].to_s, (line.target == Config.instance.formatted_channel) ? nil : line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                            sleep 1
                        end
                    else
                        Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.cr.how_many"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    end
                else
                    Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.cr.no_command"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                end
            else
                Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.cr.question"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
            end
        end

        def self.issues line
            if line.broken_formatted_message[1].nil?
                Speaker.instance.enqueue IRCMessage.new(@@github.issues_url, line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
            else
                if line.broken_formatted_message[1] == "add"
                    if !line.broken_formatted_message[2].nil?
                        subject = line.broken_formatted_message[2..-1].join(" ")
                        res = @@github.add_issue(Config.instance.channel, line.usernick, subject)
                        if res.kind_of?(String)
                            Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.issues.new_issue_url") + " " + res, line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                        else
                            Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.issues.http_error_code") + " " + res.to_s, line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                        end
                    else
                        Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.issues.subject_missing"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    end
                else
                    Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.issues.unknown_command"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                end
            end
        end

        def self.enablehskrk line
            if is_operator?(line.usernick)
                DynConfig.instance.hskrk = "on"
                Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.enablehskrk"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
            else
                Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("errors.not_authorized"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
            end
        end

        def self.disablehskrk line
            if is_operator?(line.usernick)
                DynConfig.instance.hskrk = "off"
                Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.disablehskrk"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
            else
                Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("errors.not_authorized"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
            end
        end

        def self.whois line
            if DynConfig.instance.hskrk == "on"
                data = Net::HTTP.get("whois.hskrk.pl", "/whois")
                if !data.nil?
                    begin
                        data = JSON.parse(data)
                        data["users"].each  do |u|
                            u.insert(u.length/2, "\u200e")
                        end
                        Speaker.instance.enqueue IRCMessage.new("#{Localization.instance.q("functions.whois.in_hs")} #{data["total_devices_count"]} #{data["total_devices_count"].to_s.length == 1 ? (data["total_devices_count"].to_i == 0 ? Localization.instance.q("functions.whois.devices0") : (data["total_devices_count"].to_i == 1 ? Localization.instance.q("functions.whois.devices1") : ((data["total_devices_count"].to_i > 1 && data["total_devices_count"].to_i < 5) ? (Localization.instance.q("functions.whois.devices24")) : (Localization.instance.q("functions.whois.devices59"))))) : (data["total_devices_count"].to_s[-2].to_i == 1 ? (Localization.instance.q("functions.whois.devices1019")) : ((data["total_devices_count"].to_s[-1].to_i > 1 && data["total_devices_count"].to_s[-1].to_i < 5) ? Localization.instance.q("functions.whois.devices24") : Localization.instance.q("functions.whois.devices59")))}, #{data["unknown_devices_count"]} #{data["unknown_devices_count"].to_s.length == 1 ? (data["unknown_devices_count"].to_i == 0 ? Localization.instance.q("functions.whois.unknown0") : (data["unknown_devices_count"].to_i == 1 ? Localization.instance.q("functions.whois.unknown1") : ((data["unknown_devices_count"].to_i > 1 && data["unknown_devices_count"].to_i < 5) ? (Localization.instance.q("functions.whois.unknown24")) : (Localization.instance.q("functions.whois.unknown59"))))) : (data["unknown_devices_count"].to_s[-2].to_i == 1 ? (Localization.instance.q("functions.whois.unknown1019")) : ((data["unknown_devices_count"].to_s[-1].to_i > 1 && data["unknown_devices_count"].to_s[-1].to_i < 5) ? Localization.instance.q("functions.whois.unknown24") : Localization.instance.q("functions.whois.unknown59")))}. #{data["users"].empty? ? Localization.instance.q("functions.whois.no_users") : Localization.instance.q("functions.whois.users")} #{data["users"].join(", ")}", line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    rescue JSON::JSONError => e
                        Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("errors.json"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    end
                else
                    Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("errors.connection"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                end
            else
                Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("errors.no_command"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
            end
        end

        def self.temp line
            if DynConfig.instance.hskrk == "on"
                data = Net::HTTP.get("spaceapi.hskrk.pl", "/")
                if !data.nil?
                    begin
                        data = JSON.parse(data)
                        data = data["sensors"]
                        data = data["temperature"]
                        msg = @loc.query("functions.temp") + " "
                        data.each do |d|
                            msg += "#{d["location"]}: #{d["value"]} #{d["unit"]}"
                            msg += ", " unless d == data.last
                        end
                        Speaker.instance.enqueue IRCMessage.new(msg, line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    rescue JSON::JSONError => e
                        Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("errors.json"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    end
                else
                     Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("errors.connection"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                end
            else
                Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("errors.no_command"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
            end
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