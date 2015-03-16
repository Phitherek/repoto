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
require_relative 'graphite'
module Repoto
    class Functions
        if Config.instance.github_enabled
            @@github = Github.new(Config.instance.github_access_key)
        end
        @@graphite = Repoto::Graphite.new("http://graphite.at.hskrk.pl")
        def self.parse line
            if !line.nil? && line.kind_of?(IRCLine) && line.formatted_message[0] == Config.instance.prefix && line.formatted_message[1] != Config.instance.prefix && line.formatted_message[1] != "_" && line.formatted_message[1] != " " && line.formatted_message[1] != "\n" && line.formatted_message[1] != nil
                Thread.new do
                    if line.target == Config.instance.formatted_channel && [:version, :creator, :operators, :exit, :poke, :kick, :ping, :addop, :dumpdyn, :lc, :ac, :rc, :c, :cu, :cd, :cr, :issues, :enablehskrk, :disablehskrk, :whois, :temp, :graphite, :light, :locales, :locale, :seen, :memo, :id, :remind, :ignore, :save, :restart, :help, :useralias].include?(line.broken_formatted_message[0][1..-1].to_sym)
                        self.send(line.broken_formatted_message[0][1..-1], line)
                    elsif [:version, :creator, :operators, :exit, :addop, :dumpdyn, :lc, :ac, :rc, :c, :cu, :cd, :cr, :issues, :enablehskrk, :disablehskrk, :whois, :temp, :graphite, :light, :locales, :locale, :seen, :memo, :id, :remind, :ignore, :restart, :help, :useralias].include?(line.broken_formatted_message[0][1..-1].to_sym)
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
                Reminder.instance.stop
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
                DynConfig.instance.c[line.broken_formatted_message[1].to_sym] = line.broken_formatted_message[2..-1].join(" ").to_s
                Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.ac.success"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
            else
                Speaker.instance.enqueue IRCMessage.new("#{Localization.instance.q("usage")} #{Config.instance.prefix}ac #{Localization.instance.q("functions.ac.command_name")} #{Localization.instance.q("functions.ac.command_output")}", line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
            end
        end

        def self.rc line
            if !line.broken_formatted_message[1].nil?
                if !DynConfig.instance.c.nil? && !DynConfig.instance.c[line.broken_formatted_message[1].to_sym].nil?
                    DynConfig.instance.c.delete(line.broken_formatted_message[1].to_sym)
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
                        msg = Localization.instance.q("functions.temp") + " "
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
            if DynConfig.instance.hskrk == "on"
                if line.broken_formatted_message[1] == "list" || (line.broken_formatted_message[1] == "current" && line.broken_formatted_message[2].nil?) || (line.broken_formatted_message[1] == "avg" && line.broken_formatted_message[2].nil?)
                    list = @@graphite.hs_list
                    if list.kind_of?(Array)
                        Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.graphite.available_sensors") + " "  + list.join(", "), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    else
                        Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("errors.connection"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    end
                elsif line.broken_formatted_message[1] == "current"
                    current = @@graphite.hs_current line.broken_formatted_message[2]
                    if current.kind_of?(Array)
                        Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.graphite.sensor") + " "  + current[0] + ", " + Localization.instance.q("functions.graphite.value") + " " + (current[1].nil? ? Localization.instance.q("functions.graphite.nil") : current[1].to_s) + " (" + Localization.instance.q("functions.graphite.updated_at") + " "  + current[2].to_s + ")", line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    else
                        if current == "empty"
                            Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.graphite.error_sensor_not_found") + " " + line.broken_formatted_message[2], line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                        else
                            Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("errors.connection"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                        end
                    end
                elsif line.broken_formatted_message[1] == "avg"
                    avg = @@graphite.hs_avg line.broken_formatted_message[2], line.broken_formatted_message[3]
                    if avg.kind_of?(Array)
                        Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.graphite.sensor") + " "  + avg[0] + ", " + Localization.instance.q("functions.graphite.value") + " " + avg[1].to_s + " (" + Localization.instance.q("functions.graphite.datapoints") + " " + avg[2].to_s + ")", line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    else
                        if avg == "empty"
                            Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.graphite.error_sensor_not_found") + " " + line.broken_formatted_message[2], line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                        elsif avg == "wrongdatapointsvalue"
                            Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.graphite.error_wrong_datapoints_value"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                        else
                            Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("errors.connection"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                        end
                    end
                else
                    Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.graphite.error_unknown_subcommand"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                end
            else
                Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("errors.no_command"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
            end
        end

        def self.light line
            if DynConfig.instance.hskrk == "on"
                data = Net::HTTP.get("spaceapi.hskrk.pl", "/")
                if !data.nil?
                    begin
                        data = JSON.parse(data)
                        data = data["sensors"]
                        data = data["ext_lights"]
                        lights = []
                        data = data.first
                        data.keys.each do |key|
                            if data[key] == true
                                lights << key
                            end
                        end
                        if lights.empty?
                            Speaker.instance.enqueue  IRCMessage.new(Localization.instance.q("functions.light.no_lights"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                        else
                            Speaker.instance.enqueue  IRCMessage.new("#{Localization.instance.q("functions.light.lights_in_hs")} #{lights.join(", ")}", line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                        end
                    rescue JSON::JSONError => e
                        Speaker.instance.enqueue  IRCMessage.new(Localization.instance.q("errors.json"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    end
                else
                     Speaker.instance.enqueue  IRCMessage.new(Localization.instance.q("errors.connection"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                end
            else
                Speaker.instance.enqueue  IRCMessage.new(Localization.instance.q("errors.no_command"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
            end
        end

        def self.locales line
            Speaker.instance.enqueue IRCMessage.new("Available locales: " + Localization.instance.list.join(" "), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
        end

        def self.locale line
            if is_operator?(line.usernick)
                if line.broken_formatted_message[1].nil?
                    Speaker.instance.enqueue IRCMessage.new("Current locale: #{DynConfig.instance.locale}", line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    Speaker.instance.enqueue IRCMessage.new("Usage: #{Config.instance.prefix}locale locale_to_switch_to", line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                else
                    begin
                        if Localization.instance.list.include?(line.broken_formatted_message[1])
                            DynConfig.instance.locale = line.broken_formatted_message[1]
                            Localization.instance.set(DynConfig.instance.locale)
                            Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.locale.success"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                        else
                            Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.locale.not_found"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                        end
                    rescue SimpleLion::FileException => e
                        Speaker.instance.enqueue IRCMessage.new("FileException! => #{e.to_s}", line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    rescue SimpleLion::FilesystemException => e
                        Speaker.instance.enqueue IRCMessage.new("FilesystemException! => #{e.to_s}", line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    end
                end
            else
                Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("errors.not_authorized"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
            end
        end

        def self.seen line
            if !line.broken_formatted_message[1].nil?
                seen = Seen.instance.find Alias.instance.lookup(line.broken_formatted_message[1])
                if seen.nil?
                    Speaker.instance.enqueue IRCMessage.new("#{Localization.instance.q("functions.seen.never")} #{Alias.instance.lookup(line.broken_formatted_message[1])}", line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                elsif seen == :now
                    Speaker.instance.enqueue IRCMessage.new("#{Localization.instance.q("functions.seen.user")} #{Alias.instance.lookup(line.broken_formatted_message[1])} #{Localization.instance.q("functions.seen.now")}", line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                else
                    Speaker.instance.enqueue IRCMessage.new("#{Localization.instance.q("functions.seen.user")} #{Alias.instance.lookup(line.broken_formatted_message[1])} #{Localization.instance.q("functions.seen.last_seen")} #{seen}", line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                end
            else
                Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.seen.question"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
            end
        end

        def self.memo line
            if !line.broken_formatted_message[1].nil?
                if !line.broken_formatted_message[2].nil?
                    Memo.instance.create line.broken_formatted_message[1], Alias.instance.lookup(line.usernick), line.broken_formatted_message[2..-1].join(" ")
                    Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.memo.success"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                else
                    Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.memo.question_message"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                end
            else
                Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.memo.question_user"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
            end
        end

        def self.id line
            if line.broken_formatted_message[1].nil?
                unick = line.usernick
            else
                unick = line.broken_formatted_message[1]
            end
            Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.id.user") + " " + unick + " " + Localization.instance.q("functions.id.#{ServicesAuth.instance.status(unick).to_s}"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
        end

        def self.remind line
            pline = line.broken_formatted_message[1..-1].join(" ")
            time = ""
            msg = ""
            ps = :time
            pline.each_char do |c|
                if c == '|'
                    ps = :msg
                    next
                end
                if ps == :time
                    time += c
                elsif ps == :msg
                    msg += c
                end
            end
            if !time.empty?
                if !msg.empty?
                    begin
                        Reminder.instance.create Alias.instance.lookup(line.usernick), Time.parse(time), msg
                        Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.remind.success"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    rescue => e
                        Speaker.instance.enqueue IRCMessage.new("Exception! -> " + e.to_s, line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    end
                else
                    Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.remind.question_message"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                end
            else
                Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.remind.question_time"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
            end
        end

        def self.ignore line
            if is_operator?(line.usernick)
                if !line.broken_formatted_message[1]
                    Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.ignore.available_subcommands") + " add remove", line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                else
                    if line.broken_formatted_message[1] == "add"
                        if !line.broken_formatted_message[2]
                            Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.ignore.which_user"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                        else
                            Ignore.instance.add line.broken_formatted_message[2]
                            Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.ignore.added"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                        end
                    elsif line.broken_formatted_message[1] == "remove"
                        if !line.broken_formatted_message[2]
                            Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.ignore.which_user"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                        else
                            Ignore.instance.remove line.broken_formatted_message[2]
                            Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.ignore.removed"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                        end
                    else
                        Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.ignore.available_subcommands") + " add remove", line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    end
                end
           else
                Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("errors.not_authorized"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
            end
        end

        def self.save line
            Saves.instance.save line.usernick
            Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.save"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
        end

        def self.restart line
            if is_operator?(line.usernick)
                Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.restart.channel"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                Speaker.instance.enqueue IRCMessage.new("QUIT :#{Localization.instance.q("functions.restart.quit")}", nil, :raw)
                Microphone.instance.mute
                Speaker.instance.mute
                Ping.instance.stop
                Seen.instance.dump
                Memo.instance.dump
                Reminder.instance.stop
                Reminder.instance.dump
                Ignore.instance.dump
                Alias.instance.dump
                Connection.instance.reconnect
                Alias.instance.reload
                Ignore.instance.reload
                Reminder.instance.reload
                Memo.instance.reload
                Seen.instance.reload
                DynConfig.instance.reload
                Ping.instance.reload
                Speaker.instance.unmute
                Microphone.instance.unmute
            else
                Speaker.instance.enqueue IRCMessage.newLocalization.instance.q("errors.not_authorized")
            end
        end

        def self.help line
            if line.broken_formatted_message[1].nil?
                Speaker.instance.enqueue IRCMessage.new("#{Localization.instance.q("help.available_commands")} #{Config.instance.prefix}version, #{Config.instance.prefix}creator, #{Config.instance.prefix}operators, #{Config.instance.prefix}addop,#{DynConfig.instance.hskrk == "on" ? " #{Config.instance.prefix}whois, #{Config.instance.prefix}temp, #{Config.instance.prefix}graphite, #{Config.instance.prefix}light," : ""} #{Config.instance.prefix}ac, #{Config.instance.prefix}lc, #{Config.instance.prefix}rc, #{Config.instance.prefix}c, #{Config.instance.prefix}cu, #{Config.instance.prefix}cd, #{Config.instance.prefix}cr, #{Config.instance.prefix}dumpdyn, #{Config.instance.prefix}issues, #{Config.instance.prefix}ping, #{Config.instance.prefix}poke, #{Config.instance.prefix}kick, #{Config.instance.prefix}locales, #{Config.instance.prefix}locale, #{Config.instance.prefix}seen, #{Config.instance.prefix}memo, #{Config.instance.prefix}remind, #{Config.instance.prefix}id, #{Config.instance.prefix}save, #{Config.instance.prefix}ignore, #{Config.instance.prefix}useralias, #{Config.instance.prefix}help, #{Config.instance.prefix}restart, #{Config.instance.prefix}exit", line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
            else
                case line.broken_formatted_message[1]
                when "version"
                    Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("help.version"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                when "creator"
                    Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("help.creator"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                when "operators"
                    Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("help.operators"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                when "poke"
                    Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("help.poke"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                when "ping"
                    Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("help.ping"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                when "kick"
                    Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("help.kick"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                when "ac"
                    Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("help.ac"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                when "lc"
                    Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("help.lc"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                when "c"
                    Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("help.c"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                when "rc"
                    Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("help.rc"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                when "cu"
                    Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("help.cu"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                when "cd"
                    Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("help.cd"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                when "cr"
                    Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("help.cr"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                when "seen"
                    Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("help.seen"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                when "memo"
                    Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("help.memo"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                when "remind"
                    Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("help.remind"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                when "save"
                    Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("help.save"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                when "issues"
                    Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("help.issues"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                when "id"
                    Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("help.id"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                when "whois"
                    if DynConfig.instance.hskrk == "on"
                        Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("help.whois"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    else
                        Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("help.no_command"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    end
                when "temp"
                    if DynConfig.instance.hskrk == "on"
                        Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("help.temp"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    else
                        Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("help.no_command"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    end
                when "graphite"
                    if DynConfig.instance.hskrk == "on"
                        Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("help.graphite"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    else
                        Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("help.no_command"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    end
                when "light"
                    if DynConfig.instance.hskrk == "on"
                        Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("help.light"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    else
                        Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("help.no_command"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    end
                when "exit"
                    if oper
                        Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("help.exit"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    else
                        Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("help.not_operator"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    end
                when "restart"
                    if oper
                        Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("help.restart"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    else
                        Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("help.not_operator"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    end
                when "addop"
                    if oper
                        Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("help.addop"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    else
                        Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("help.not_operator"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    end
                when "dumpdyn"
                    if oper
                        Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("help.dumpdyn"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    else
                        Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("help.not_operator"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    end
                when "locales"
                    if oper
                        Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("help.locales"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    else
                        Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("help.not_operator"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    end
                when "locale"
                    if oper
                        Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("help.locale"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    else
                        Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("help.not_operator"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    end
                when "ignore"
                    if oper
                        Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("help.ignore"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    else
                        Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("help.not_operator"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    end
                when "useralias"
                    Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("help.useralias"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                else
                    Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("help.no_command"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                end
            end
        end

        def self.useralias line
            if line.broken_formatted_message[1].nil?
                Speaker.instance.enqueue IRCMessage.new("#{Localization.instance.q("usage")} #{Config.instance.prefix}useralias [add|remove|nick-for-lookup] [base-nick] [alias]", line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
            elsif line.broken_formatted_message[1] == "add"
                if line.broken_formatted_message[2] != nil && line.broken_formatted_message[3] != nil
                    if Alias.instance.add line.broken_formatted_message[2], line.broken_formatted_message[3]
                        Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.useralias.added"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    else
                        Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.useralias.error"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                    end
                else
                    Speaker.instance.enqueue IRCMessage.new("#{Localization.instance.q("usage")} #{Config.instance.prefix}useralias [add|remove|nick-for-lookup] [base-nick] [alias]", line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                end
            elsif line.broken_formatted_message[1] == "remove"
                if line.broken_formatted_message[2] != nil && line.broken_formatted_message[3] != nil
                    Alias.instance.remove line.broken_formatted_message[2], line.broken_formatted_message[3]
                    Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("functions.useralias.removed"), line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                else
                    Speaker.instance.enqueue IRCMessage.new("#{Localization.instance.q("usage")} #{Config.instance.prefix}useralias [add|remove|nick-for-lookup] [base-nick] [alias]", line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                end
            else
                Speaker.instance.enqueue IRCMessage.new(Alias.instance.lookup(line.broken_formatted_message[1]), nil, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
            end
        end

        private

        def self.is_operator?(usernick)
            !usernick.nil? && DynConfig.instance.operators.include?(usernick) && ServicesAuth.instance.status(usernick) == :logged_in
        end
    end
end