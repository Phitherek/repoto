require 'socket'
require 'yaml'
require 'fileutils'
require 'net/http'
require 'json'
require 'simplelion-ruby'
require 'unicode'
require 'time'
require_relative 'seen'
require_relative 'memo'
require_relative 'saves'
require_relative 'reminder'
require_relative 'redmine'
require_relative 'github'
require_relative 'graphite'
require_relative 'ignore'

module Repoto
    class Bot
        def initialize
            if File.exists?("config.yml")
                @config = YAML.load_file("config.yml")
            else
                raise "Could not read config!"
            end
            if !@config
                raise "Could not read config!"
            end
            if File.exists?("dynconfig.yml")
                @dynconfig = YAML.load_file("dynconfig.yml")
            else
                @dynconfig = {}
            end
            if !@dynconfig
                @dynconfig = {}
            end
            @channel = "#" + @config[:channel]
            @nick = "Repoto"
            @suffix = @config[:suffix]
            @version = "2.3.5"
            @creator = "Phitherek_"
            @server = @config[:server]
            @port = @config[:port].to_i
            @prefix = @config[:prefix]
            @loc = SimpleLion::Localization.new("locales", @dynconfig[:locale])
            @imsg_enabled = false
            @nickserv_present = true
            @seen = Repoto::Seen.new
            @memo = Repoto::Memo.new
            @saves = Repoto::Saves.new
            @reminder = Repoto::Reminder.new
            @hsgraphite = Repoto::Graphite.new("http://graphite.at.hskrk.pl")
            @ignore = Repoto::Ignore.new
            if @config[:github_enabled]
                @github = Repoto::Github.new(@config[:github_access_key])
                if @github.connection?
                    puts "GitHub connection successful!"
                else
                    puts "GitHub connection failed!"
                end
            end
            if @config[:redmine_enabled]
                @redmine = Repoto::Redmine.new(@config[:redmine_url], @config[:redmine_api_key])
            end
            if @config[:debug_log_enabled]
                @dlog = File.open(@config[:debug_log_path], "a")
                puts "Opened debug log..."
            end

            puts "Connecting..."

            connect
            begin
                while line = @conn.gets
                    begin
                        oper = false
                        auth = false
                        line.force_encoding 'utf-8'
                        dlog_server line
                        la = line.split(" ")
                        if la[0][0] == ":" && la[1] == "001"
                            join_channel
                            send_nickserv_check
                        end
                        if la[0] == "PING"
                            puts "Ping-pong..."
                            dlog_bot "PONG #{la[1]}"
                            @conn.puts "PONG #{la[1]}"
                        end
                        if la[0] == "ERROR"
                            puts "Server error - restarting..."
                            puts "Closing connection..."
                            @conn.close
                            puts "Dumping seen data..."
                            @seen.dump
                            puts "Dumping memo data..."
                            @memo.dump
                            puts "Dumping reminders..."
                            @reminder.dump
                            puts "Dumping ignores..."
                            @ignore.dump
                            sleep 60
                            puts "Reconnecting..."
                            if File.exists?("config.yml")
                                @config = YAML.load_file("config.yml")
                            else
                                raise "Could not read config!"
                            end
                            if !@config
                                raise "Could not read config!"
                            end
                            if File.exists?("dynconfig.yml")
                                @dynconfig = YAML.load_file("dynconfig.yml")
                            else
                                @dynconfig = {}
                            end
                            if !@dynconfig
                                @dynconfig = {}
                            end
                            @loc = SimpleLion::Localization.new("locales", @dynconfig[:locale])
                            connect
                        end
                        if la[0][0] == ":"
                            if la[1] == "CAP" && la[2] == "#{@nick}#{!@suffix.nil? ? "|#{@suffix}" : ""}" && la[3] == "ACK" && la[4] == ":identify-msg"
                                @imsg_enabled = true
                            elsif la[1] == "401" && la[3] == "NickServ"
                                @nickserv_present = false
                            elsif la[1] == "433"
                                raise "Nickname already in use!"
                            end
                        end
                        usernick = ""
                        la[0].chars.each do |l|
                            if l != ":"
                                if l == "!"
                                    break
                                else
                                    usernick += l
                                end
                            end
                        end
                        #puts "Nick: " + usernick
                        if @dynconfig[:operators].include?(usernick)
                            #puts "#{usernick} is an operator."
                            oper = true
                        end
                        skipparse = false
                        if la[1] == "JOIN"
                            puts "*** #{usernick} has joined the channel."
                            @saves.log "*** #{usernick} has joined the channel."
                            @seen.update usernick, :join
                            skipparse = true
                        elsif la[1] == "PART" || la[1] == "QUIT"
                            if usernick == "#{@nick}|#{@suffix}" && Unicode.upcase(la[3]).include?("PING TIMEOUT")
                                puts "Ping timeout - restarting..."
                                puts "Closing connection..."
                                @conn.close
                                puts "Dumping seen data..."
                                @seen.dump
                                puts "Dumping memo data..."
                                @memo.dump
                                puts "Dumping reminders..."
                                @reminder.dump
                                puts "Dumping ignores..."
                                @ignore.dump
                                sleep 5
                                puts "Reconnecting..."
                                if File.exists?("config.yml")
                                    @config = YAML.load_file("config.yml")
                                else
                                    raise "Could not read config!"
                                end
                                if !@config
                                    raise "Could not read config!"
                                end
                                if File.exists?("dynconfig.yml")
                                    @dynconfig = YAML.load_file("dynconfig.yml")
                                else
                                    @dynconfig = {}
                                end
                                if !@dynconfig
                                    @dynconfig = {}
                                end
                                @loc = SimpleLion::Localization.new("locales", @dynconfig[:locale])
                                connect
                                next
                            else
                                puts "*** #{usernick} has left the channel."
                                @saves.log "*** #{usernick} has left the channel."
                                @seen.update usernick, :part
                                next
                            end
                        elsif la[1] == "KICK"
                            usernick = la[3]
                            puts "*** #{usernick} has been kicked from the channel."
                            @saves.log "*** #{usernick} has left the channel."
                            @seen.update usernick, :part
                            if usernick == "#{@nick}#{!@suffix.nil? ? "|#{@suffix}" : ""}"
                                @conn.close
                                sleep 5
                                if File.exists?("config.yml")
                                    @config = YAML.load_file("config.yml")
                                else
                                    raise "Could not read config!"
                                end
                                if !@config
                                    raise "Could not read config!"
                                end
                                if File.exists?("dynconfig.yml")
                                    @dynconfig = YAML.load_file("dynconfig.yml")
                                else
                                    @dynconfig = {}
                                end
                                if !@dynconfig
                                    @dynconfig = {}
                                end
                                @loc = SimpleLion::Localization.new("locales", @dynconfig[:locale])
                                connect
                            end
                            next
                        elsif la[1] != "PRIVMSG"
                            next
                        else
                            @seen.update usernick, :join
                        end
                        if @seen.find(usernick) == :now
                            if !@reminder.current_for_user(usernick).nil? && !@reminder.current_for_user(usernick).empty?
                                @reminder.current_for_user(usernick).each do |r|
                                    send_message_to_user usernick, "#{@loc.query("functions.remind.reminder_for")} #{r[:time]}: #{r[:msg]}"
                                    sleep(2)
                                end
                                @reminder.clean_for_user usernick
                            end
                        end
                        if skipparse
                            next
                        end
                        if la[2] == @channel
                            #puts "Message is for the channel"
                        else
                            #puts "Skipping parse"
                            next
                        end
                        msg = la[3..-1].join(" ") if !la[3].nil?
                        if msg.nil? || msg.empty?
                            #puts "Message is nil!"
                            next
                        else
                            msg = msg[1..-1]
                            if @imsg_enabled
                                if msg[0] == "+"
                                    auth = true
                                else
                                    oper = false
                                end
                                msg = msg[1..-1]
                            elsif @nickserv_present
                                dlog_bot "PRIVMSG NickServ ACC #{usernick}"
                                @conn.puts "PRIVMSG NickServ ACC #{usernick}"
                                ns_response = @conn.gets
                                dlog_server ns_response
                                ns_response.force_encoding("utf-8")
                                ns_response = ns_response.split(" ")
                                if ns_response[0][0] == ":" && ns_response[1] == "NOTICE" && ns_response[2] == "#{@nick}#{!@suffix.nil? ? "|#{@suffix}" : ""}"
                                    if ns_response[5] == "3"
                                        auth = true
                                    else
                                        oper = false
                                    end
                                end
                            end
                            if msg.nil? || msg.empty?
                                next
                            end
                            if msg[0] == @prefix && msg[1] != @prefix && msg[1] != "_" && msg[1] != " " && msg[1] != "\n" && msg[1] != nil && !@ignore.has?(usernick)
                                cmd = msg[1..-1]
                                cmd = cmd.split(" ")
                                case cmd[0]
                                when "version"
                                    send_message_to_user usernick, "#{@loc.query("functions.version")} #{@version}"
                                when "creator"
                                    send_message_to_user usernick, "#{@loc.query("functions.creator")} #{@creator}"
                                when "operators"
                                    send_message_to_user usernick, "#{@loc.query("functions.operators")} #{@dynconfig[:operators].join(" ")}"
                                when "exit"
                                    if oper
                                        send_message_to_user usernick, @loc.query("functions.exit.channel")
                                        @conn.puts "QUIT :#{@loc.query("functions.exit.quit")}"
                                        @seen.dump
                                        @memo.dump
                                        @reminder.dump
                                        break
                                    else
                                        send_message_to_user usernick, @loc.query("errors.not_authorized")
                                    end
                                when "poke"
                                    if cmd[1].nil?
                                        send_message_to_user usernick, @loc.query("functions.poke.question")
                                    else
                                        perform_action "#{@loc.query("functions.poke.msg1")} #{cmd[1]} #{@loc.query("functions.poke.msg2")} #{usernick}#{@loc.query("functions.poke.msg3")}"
                                    end
                                when "kick"
                                    if cmd[1].nil?
                                        send_message_to_user usernick, @loc.query("functions.kick.question")
                                    else
                                        perform_action "#{@loc.query("functions.kick.msg1")} #{cmd[1]} #{@loc.query("functions.poke.msg2")} #{usernick}#{@loc.query("functions.kick.msg3")}"
                                    end
                                when "ping"
                                    if cmd[1].nil?
                                        send_message_to_user usernick, @loc.query("functions.ping.question")
                                    else
                                        send_message_to_user cmd[1], "#{@loc.query("functions.ping.msg")} #{usernick}."
                                    end
                                when "addop"
                                    if oper
                                        if !cmd[1].nil?
                                            @dynconfig[:operators] << cmd[1]
                                            send_message_to_user cmd[1], "#{usernick} #{@loc.query("functions.addop")}"
                                        else
                                            send_message_to_user usernick, "#{@loc.query("usage")} #{@prefix}addop user_nick"
                                        end
                                    else
                                        send_message_to_user usernick, @loc.query("errors.not_authorized")
                                    end
                                when "dumpdyn"
                                    if oper
                                        FileUtils.rm("dynconfig.yml")
                                        File.open("dynconfig.yml", "w") do |f|
                                            f << YAML.dump(@dynconfig)
                                        end
                                        send_message_to_user usernick, @loc.query("functions.dumpdyn")
                                    else
                                        send_message_to_user usernick, @loc.query("errors.not_authorized")
                                    end
                                when "lc"
                                    if !@dynconfig[:c].nil?
                                        send_message_to_user usernick, "#{@loc.query("functions.lc.prelist")} " + @dynconfig[:c].keys.join(" ").to_s
                                    else
                                        send_message_to_user usernick, @loc.query("functions.lc.no_commands")
                                    end
                                when "ac"
                                    if !cmd[1].nil? && !cmd[2].nil?
                                        @dynconfig[:c] ||= {}
                                        @dynconfig[:c][cmd[1].to_sym] = cmd[2..-1].join(" ").to_s
                                        send_message_to_user usernick, @loc.query("functions.ac.success")
                                    else
                                        send_message_to_user usernick, "#{@loc.query("usage")} #{@prefix}ac #{@loc.query("functions.ac.command_name")} #{@loc.query("functions.ac.command_output")}"
                                    end
                                when "rc"
                                    if !cmd[1].nil?
                                        if !@dynconfig[:c].nil? && !@dynconfig[:c][cmd[1].to_sym].nil?
                                            @dynconfig[:c].delete(cmd[1].to_sym)
                                            send_message_to_user usernick, @loc.query("functions.rc.success")
                                        else
                                            send_message_to_user usernick, @loc.query("functions.rc.no_command")
                                        end
                                    else
                                        send_message_to_user usernick, "#{@loc.query "usage"} #{@prefix}rc #{@loc.query("functions.rc.command_name")}"
                                    end
                                when "c"
                                    if !cmd[1].nil?
                                        if !@dynconfig[:c].nil? && !@dynconfig[:c][cmd[1].to_sym].nil?
                                            send_message @dynconfig[:c][cmd[1].to_sym].to_s
                                        else
                                            send_message_to_user usernick, @loc.query("functions.c.no_command")
                                        end
                                    else
                                        send_message_to_user usernick, @loc.query("functions.c.question")
                                    end
                                when "cu"
                                    if !cmd[1].nil?
                                        if !@dynconfig[:c].nil? && !@dynconfig[:c][cmd[1].to_sym].nil?
                                            send_message Unicode.upcase(@dynconfig[:c][cmd[1].to_sym].to_s.force_encoding("utf-8"))
                                        else
                                            send_message_to_user usernick, @loc.query("functions.c.no_command")
                                        end
                                    else
                                        send_message_to_user usernick, @loc.query("functions.c.question")
                                    end
                                when "cd"
                                    if !cmd[1].nil?
                                        if !@dynconfig[:c].nil? && !@dynconfig[:c][cmd[1].to_sym].nil?
                                            send_message Unicode.downcase(@dynconfig[:c][cmd[1].to_sym].to_s.force_encoding("utf-8"))
                                        else
                                            send_message_to_user usernick, @loc.query("functions.c.no_command")
                                        end
                                    else
                                        send_message_to_user usernick, @loc.query("functions.c.question")
                                    end
                                when "cr"
                                    if !cmd[1].nil?
                                        if !@dynconfig[:c].nil? && !@dynconfig[:c][cmd[1].to_sym].nil?
                                            if !cmd[2].nil?
                                                cmd[2].to_i.times do
                                                    send_message @dynconfig[:c][cmd[1].to_sym].to_s
                                                    sleep 2
                                                end
                                            else
                                              send_message_to_user usernick, @loc.query("functions.cr.how_many")
                                            end
                                        else
                                            send_message_to_user usernick, @loc.query("functions.cr.no_command")
                                        end
                                    else
                                        send_message_to_user usernick, @loc.query("functions.cr.question")
                                    end
                                when "issues"
                                    if cmd[1].nil?
                                        send_message_to_user usernick, @github.issues_url
                                    else
                                        if cmd[1] == "add"
                                            if !cmd[2].nil?
                                                subject = cmd[2..-1].join(" ")
                                                res = @github.add_issue(@config[:channel], usernick, subject)
                                                if res.kind_of?(String)
                                                    send_message_to_user usernick, @loc.query("functions.issues.new_issue_url") + " " + res
                                                else
                                                    send_message_to_user usernick, @loc.query("functions.issues.http_error_code") + " " + res.to_s
                                                end
                                            else
                                                send_message_to_user usernick, @loc.query("functions.issues.subject_missing")
                                            end
                                        else
                                            send_message_to_user usernick, @loc.query("functions.issues.unknown_command")
                                        end
                                    end
                                when "enablehskrk"
                                    if oper
                                        @dynconfig[:hskrk] = "on"
                                        send_message_to_user usernick, @loc.query("functions.enablehskrk")
                                    else
                                        send_message_to_user usernick, @loc.query("errors.not_authorized")
                                    end
                                when "disablehskrk"
                                    if oper
                                        @dynconfig[:hskrk] = "off"
                                        send_message_to_user usernick, @loc.query("functions.disablehskrk")
                                    else
                                        send_message_to_user usernick, @loc.query("errors.not_authorized")
                                    end
                                when "enablemp"
                                    if @dynconfig[:hskrk] == "on"
                                        if oper
                                            @dynconfig[:mp] = "on"
                                            send_message_to_user usernick, @loc.query("functions.enablemp")
                                        else
                                            send_message_to_user usernick, @loc.query("errors.not_authorized")
                                        end
                                    else
                                        send_message_to_user usernick, @loc.query("errors.no_command")
                                    end
                                when "disablemp"
                                    if @dynconfig[:hskrk] == "on"
                                        if oper
                                            @dynconfig[:mp] = "off"
                                            send_message_to_user usernick, @loc.query("functions.disablemp")
                                        else
                                            send_message_to_user usernick, @loc.query("errors.not_authorized")
                                        end
                                    else
                                        send_message_to_user usernick, @loc.query("errors.no_command")
                                    end
                                when "whois"
                                    if @dynconfig[:hskrk] == "on"
                                        data = Net::HTTP.get("whois.hskrk.pl", "/whois")
                                        if !data.nil?
                                            begin
                                                data = JSON.parse(data)
                                                data["users"].each  do |u|
                                                    u.insert(u.length/2, "\u200e")
                                                end
                                                send_message_to_user usernick, "#{@loc.query("functions.whois.in_hs")} #{data["total_devices_count"]} #{data["total_devices_count"].to_s.length == 1 ? (data["total_devices_count"].to_i == 0 ? @loc.query("functions.whois.devices0") : (data["total_devices_count"].to_i == 1 ? @loc.query("functions.whois.devices1") : ((data["total_devices_count"].to_i > 1 && data["total_devices_count"].to_i < 5) ? (@loc.query("functions.whois.devices24")) : (@loc.query("functions.whois.devices59"))))) : (data["total_devices_count"].to_s[-2].to_i == 1 ? (@loc.query("functions.whois.devices1019")) : ((data["total_devices_count"].to_s[-1].to_i > 1 && data["total_devices_count"].to_s[-1].to_i < 5) ? @loc.query("functions.whois.devices24") : @loc.query("functions.whois.devices59")))}, #{data["unknown_devices_count"]} #{data["unknown_devices_count"].to_s.length == 1 ? (data["unknown_devices_count"].to_i == 0 ? @loc.query("functions.whois.unknown0") : (data["unknown_devices_count"].to_i == 1 ? @loc.query("functions.whois.unknown1") : ((data["unknown_devices_count"].to_i > 1 && data["unknown_devices_count"].to_i < 5) ? (@loc.query("functions.whois.unknown24")) : (@loc.query("functions.whois.unknown59"))))) : (data["unknown_devices_count"].to_s[-2].to_i == 1 ? (@loc.query("functions.whois.unknown1019")) : ((data["unknown_devices_count"].to_s[-1].to_i > 1 && data["unknown_devices_count"].to_s[-1].to_i < 5) ? @loc.query("functions.whois.unknown24") : @loc.query("functions.whois.unknown59")))}. #{data["users"].empty? ? @loc.query("functions.whois.no_users") : @loc.query("functions.whois.users")} #{data["users"].join(", ")}"
                                            rescue JSON::JSONError => e
                                                send_message_to_user usernick, @loc.query("errors.json")
                                            end
                                        else
                                            send_message_to_user usernick, @loc.query("errors.connection")
                                        end
                                    else
                                        send_message_to_user usernick, @loc.query("errors.no_command")
                                    end
                                when "temp"
                                    if @dynconfig[:hskrk] == "on"
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
                                                send_message_to_user usernick, msg
                                            rescue JSON::JSONError => e
                                                send_message_to_user usernick, @loc.query("errors.json")
                                            end
                                        else
                                             send_message_to_user usernick, @loc.query("errors.connection")
                                        end
                                    else
                                        send_message_to_user usernick, @loc.query("errors.no_command")
                                    end
                                when "graphite"
                                    if @dynconfig[:hskrk] == "on"
                                        if cmd[1] == "list" || (cmd[1] == "current" && cmd[2].nil?) || (cmd[1] == "avg" && cmd[2].nil?)
                                            list = @hsgraphite.hs_list
                                            if list.kind_of?(Array)
                                                send_message_to_user usernick, @loc.query("functions.graphite.available_sensors") + " "  + list.join(", ")
                                            else
                                                send_message_to_user usernick, @loc.query("errors.connection")
                                            end
                                        elsif cmd[1] == "current"
                                            current = @hsgraphite.hs_current cmd[2]
                                            if current.kind_of?(Array)
                                                send_message_to_user usernick, @loc.query("functions.graphite.sensor") + " "  + current[0] + ", " + @loc.query("functions.graphite.value") + " " + (current[1].nil? ? @loc.query("functions.graphite.nil") : current[1].to_s) + " (" + @loc.query("functions.graphite.updated_at") + " "  + current[2].to_s + ")"
                                            else
                                                if current == "empty"
                                                    send_message_to_user usernick, @loc.query("functions.graphite.error_sensor_not_found") + " " + cmd[2]
                                                else
                                                    send_message_to_user usernick, @loc.query("errors.connection")
                                                end
                                            end
                                        elsif cmd[1] == "avg"
                                            avg = @hsgraphite.hs_avg cmd[2], cmd[3]
                                            if avg.kind_of?(Array)
                                                send_message_to_user usernick, @loc.query("functions.graphite.sensor") + " "  + avg[0] + ", " + @loc.query("functions.graphite.value") + " " + avg[1].to_s + " (" + @loc.query("functions.graphite.datapoints") + " " + avg[2].to_s + ")"
                                            else
                                                if avg == "empty"
                                                    send_message_to_user usernick, @loc.query("functions.graphite.error_sensor_not_found") + " " + cmd[2]
                                                elsif avg == "wrongdatapointsvalue"
                                                    send_message_to_user usernick, @loc.query("functions.graphite.error_wrong_datapoints_value")
                                                else
                                                    send_message_to_user usernick, @loc.query("errors.connection")
                                                end
                                            end
                                        else
                                            send_message_to_user usernick, @loc.query("functions.graphite.error_unknown_subcommand")
                                        end
                                    else
                                        send_message_to_user usernick, @loc.query("errors.no_command")
                                    end
                                when "light"
                                    if @dynconfig[:hskrk] == "on"
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
                                                    send_message_to_user usernick, @loc.query("functions.light.no_lights")
                                                else
                                                    send_message_to_user usernick, "#{@loc.query("functions.light.lights_in_hs")} #{lights.join(", ")}"
                                                end
                                            rescue JSON::JSONError => e
                                                send_message_to_user usernick, @loc.query("errors.json")
                                            end
                                        else
                                             send_message_to_user usernick, @loc.query("errors.connection")
                                        end
                                    else
                                        send_message_to_user usernick, @loc.query("errors.no_command")
                                    end
                                when "locales"
                                    send_message_to_user usernick, "Available locales: " + @loc.localeList.join(" ")
                                when "locale"
                                    if oper
                                        if cmd[1].nil?
                                            send_message_to_user usernick, "Current locale: #{@dynconfig[:locale]}"
                                            send_message_to_user usernick, "Usage: #{@prefix}locale locale_to_switch_to"
                                        else
                                            begin
                                                if @loc.localeList.include?(cmd[1])
                                                    @dynconfig[:locale] = cmd[1]
                                                    @loc.setLocale(@dynconfig[:locale])
                                                    send_message_to_user usernick, @loc.query("functions.locale.success")
                                                else
                                                    send_message_to_user usernick, @loc.query("functions.locale.not_found")
                                                end
                                            rescue SimpleLion::FileException => e
                                                send_message_to_user usernick, "FileException! => #{e.to_s}"
                                            rescue SimpleLion::FilesystemException => e
                                                send_message_to_user usernick, "FilesystemException! => #{e.to_s}"
                                            end
                                        end
                                    else
                                        send_message_to_user usernick, @loc.query("errors.not_authorized")
                                    end
                                when "seen"
                                    if !cmd[1].nil?
                                        seen = @seen.find cmd[1]
                                        if seen.nil?
                                            send_message_to_user usernick, "#{@loc.query("functions.seen.never")} #{cmd[1]}"
                                        elsif seen == :now
                                            send_message_to_user usernick, "#{@loc.query("functions.seen.user")} #{cmd[1]} #{@loc.query("functions.seen.now")}"
                                        else
                                            send_message_to_user usernick, "#{@loc.query("functions.seen.user")} #{cmd[1]} #{@loc.query("functions.seen.last_seen")} #{seen}"
                                        end
                                    else
                                        send_message_to_user usernick, @loc.query("functions.seen.question")
                                    end
                                when "memo"
                                    if !cmd[1].nil?
                                        if !cmd[2].nil?
                                            @memo.create cmd[1], usernick, cmd[2..-1].join(" ")
                                            send_message_to_user usernick, @loc.query("functions.memo.success")
                                        else
                                            send_message_to_user usernick, @loc.query("functions.memo.question_message")
                                        end
                                    else
                                        send_message_to_user usernick, @loc.query("functions.memo.question_user")
                                    end
                                when "id"
                                    if @nickserv_present
                                        if cmd[1].nil?
                                            unick = usernick
                                        else
                                            unick = cmd[1]
                                        end
                                        dlog_bot "PRIVMSG NickServ ACC #{unick}"
                                        @conn.puts "PRIVMSG NickServ ACC #{unick}"
                                        ns_response = @conn.gets
                                        ns_response.force_encoding("utf-8")
                                        dlog_server ns_response
                                        ns_response = ns_response.split(" ")
                                        if ns_response[0][0] == ":" && ns_response[1] == "NOTICE" && ns_response[2] == "#{@nick}#{!@suffix.nil? ? "|#{@suffix}" : ""}"
                                            if ns_response[5] == "3"
                                                send_message_to_user usernick, @loc.query("functions.id.user") + " " + unick + " " + @loc.query("functions.id.logged_in")
                                            elsif ns_response[5] == "2"
                                                send_message_to_user usernick, @loc.query("functions.id.user") + " " + unick + " " + @loc.query("functions.id.not_logged_in_recognized")
                                            elsif ns_response[5] == "1"
                                                send_message_to_user usernick, @loc.query("functions.id.user") + " " + unick + " " + @loc.query("functions.id.exists_not_logged_in")
                                            elsif ns_response[5] == "0"
                                                send_message_to_user usernick, @loc.query("functions.id.user") + " " + unick + " " + @loc.query("functions.id.does_not_exist")
                                            else
                                                send_message_to_user usernick, @loc.query("functions.id.unknown_reponse")
                                            end
                                        end
                                    else
                                        send_message_to_user usernick, @loc.query("functions.id.no_nickserv")
                                    end
                                when "remind"
                                    pcmd = cmd[1..-1].join(" ")
                                    time = ""
                                    msg = ""
                                    ps = :time
                                    pcmd.each_char do |c|
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
                                                @reminder.create usernick, Time.parse(time), msg
                                                send_message_to_user usernick, @loc.query("functions.remind.success")
                                            rescue => e
                                                send_message_to_user usernick, "Exception! -> " + e.to_s
                                            end
                                        else
                                            send_message_to_user usernick, @loc.query("functions.remind.question_message")
                                        end
                                    else
                                        send_message_to_user usernick, @loc.query("functions.remind.question_time")
                                    end
                                when "ignore"
                                    if oper
                                        if !cmd[1]
                                            send_message_to_user usernick, @loc.query("functions.ignore.available_subcommands") + " add remove"
                                        else
                                            if cmd[1] == "add"
                                                if !cmd[2]
                                                    send_message_to_user usernick, @loc.query("functions.ignore.which_user")
                                                else
                                                    @ignore.add cmd[2]
                                                    send_message_to_user usernick, @loc.query("functions.ignore.added")
                                                end
                                            elsif cmd[1] == "remove"
                                                if !cmd[2]
                                                    send_message_to_user usernick, @loc.query("functions.ignore.which_user")
                                                else
                                                    @ignore.remove cmd[2]
                                                    send_message_to_user usernick, @loc.query("functions.ignore.removed")
                                                end
                                            else
                                                send_message_to_user usernick, @loc.query("functions.ignore.available_subcommands") + " add remove"
                                            end
                                        end
                                    else
                                        send_message_to_user usernick, @loc.query("errors.not_authorized")
                                    end
                                when "save"
                                    @saves.save usernick
                                    send_message_to_user usernick, @loc.query("functions.save")
                                when "restart"
                                    if oper
                                        send_message_to_user usernick, @loc.query("functions.restart.channel")
                                        @conn.puts "QUIT :#{@loc.query("functions.restart.quit")}"
                                        puts "Restarting on operators' request..."
                                        puts "Closing connection..."
                                        @conn.close
                                        puts "Dumping seen data..."
                                        @seen.dump
                                        puts "Dumping memo data..."
                                        @memo.dump
                                        puts "Dumping reminders..."
                                        @reminder.dump
                                        puts "Dumping ignores..."
                                        @ignore.dump
                                        sleep 5
                                        if File.exists?("config.yml")
                                            @config = YAML.load_file("config.yml")
                                        else
                                            raise "Could not read config!"
                                        end
                                        if !@config
                                            raise "Could not read config!"
                                        end
                                        if File.exists?("dynconfig.yml")
                                            @dynconfig = YAML.load_file("dynconfig.yml")
                                        else
                                            @dynconfig = {}
                                        end
                                        if !@dynconfig
                                            @dynconfig = {}
                                        end
                                        @loc = SimpleLion::Localization.new("locales", @dynconfig[:locale])
                                        connect
                                    else
                                        send_message_to_user usernick, @loc.query("errors.not_authorized")
                                    end
                                when "help"
                                    if cmd[1].nil?
                                        send_message_to_user usernick, "#{@loc.query("help.available_commands")} #{@prefix}version, #{@prefix}creator, #{@prefix}operators, #{@prefix}addop,#{@dynconfig[:hskrk] == "on" ? " #{@prefix}whois, #{@prefix}temp, #{@prefix}graphite, #{@prefix}light," : ""} #{@prefix}ac, #{@prefix}lc, #{@prefix}rc, #{@prefix}c, #{@prefix}cu, #{@prefix}cd, #{@prefix}cr, #{@prefix}dumpdyn, #{@prefix}issues, #{@prefix}ping, #{@prefix}poke, #{@prefix}kick, #{@prefix}locales, #{@prefix}locale, #{@prefix}seen, #{@prefix}memo, #{@prefix}remind, #{@prefix}id, #{@prefix}save, #{@prefix}ignore, #{@prefix}help, #{@prefix}restart, #{@prefix}exit"
                                    else
                                        case cmd[1]
                                        when "version"
                                            send_message_to_user usernick, @loc.query("help.version")
                                        when "creator"
                                            send_message_to_user usernick, @loc.query("help.creator")
                                        when "operators"
                                            send_message_to_user usernick, @loc.query("help.operators")
                                        when "poke"
                                            send_message_to_user usernick, @loc.query("help.poke")
                                        when "ping"
                                            send_message_to_user usernick, @loc.query("help.ping")
                                        when "kick"
                                            send_message_to_user usernick, @loc.query("help.kick")
                                        when "ac"
                                            send_message_to_user usernick, @loc.query("help.ac")
                                        when "lc"
                                            send_message_to_user usernick, @loc.query("help.lc")
                                        when "c"
                                            send_message_to_user usernick, @loc.query("help.c")
                                        when "rc"
                                            send_message_to_user usernick, @loc.query("help.rc")
                                        when "cu"
                                            send_message_to_user usernick, @loc.query("help.cu")
                                        when "cd"
                                            send_message_to_user usernick, @loc.query("help.cd")
                                        when "cr"
                                            send_message_to_user usernick, @loc.query("help.cr")
                                        when "seen"
                                            send_message_to_user usernick, @loc.query("help.seen")
                                        when "memo"
                                            send_message_to_user usernick, @loc.query("help.memo")
                                        when "remind"
                                            send_message_to_user usernick, @loc.query("help.remind")
                                        when "save"
                                            send_message_to_user usernick, @loc.query("help.save")
                                        when "issues"
                                            send_message_to_user usernick, @loc.query("help.issues")
                                        when "id"
                                            send_message_to_user usernick, @loc.query("help.id")
                                        when "whois"
                                            if @dynconfig[:hskrk] == "on"
                                                send_message_to_user usernick, @loc.query("help.whois")
                                            else
                                                send_message_to_user usernick, @loc.query("help.no_command")
                                            end
                                        when "temp"
                                            if @dynconfig[:hskrk] == "on"
                                                send_message_to_user usernick, @loc.query("help.temp")
                                            else
                                                send_message_to_user usernick, @loc.query("help.no_command")
                                            end
                                        when "graphite"
                                            if @dynconfig[:hskrk] == "on"
                                                send_message_to_user usernick, @loc.query("help.graphite")
                                            else
                                                send_message_to_user usernick, @loc.query("help.no_command")
                                            end
                                        when "light"
                                            if @dynconfig[:hskrk] == "on"
                                                send_message_to_user usernick, @loc.query("help.light")
                                            else
                                                send_message_to_user usernick, @loc.query("help.no_command")
                                            end
                                        when "exit"
                                            if oper
                                                send_message_to_user usernick, @loc.query("help.exit")
                                            else
                                                send_message_to_user usernick, @loc.query("help.not_operator")
                                            end
                                        when "restart"
                                            if oper
                                                send_message_to_user usernick, @loc.query("help.restart")
                                            else
                                                send_message_to_user usernick, @loc.query("help.not_operator")
                                            end
                                        when "addop"
                                            if oper
                                                send_message_to_user usernick, @loc.query("help.addop")
                                            else
                                                send_message_to_user usernick, @loc.query("help.not_operator")
                                            end
                                        when "dumpdyn"
                                            if oper
                                                send_message_to_user usernick, @loc.query("help.dumpdyn")
                                            else
                                                send_message_to_user usernick, @loc.query("help.not_operator")
                                            end
                                        when "locales"
                                            if oper
                                                send_message_to_user usernick, @loc.query("help.locales")
                                            else
                                                send_message_to_user usernick, @loc.query("help.not_operator")
                                            end
                                        when "locale"
                                            if oper
                                                send_message_to_user usernick, @loc.query("help.locale")
                                            else
                                                send_message_to_user usernick, @loc.query("help.not_operator")
                                            end
                                        when "ignore"
                                            if oper
                                                send_message_to_user usernick, @loc.query("help.ignore")
                                            else
                                                send_message_to_user usernick, @loc.query("help.not_operator")
                                            end
                                        else
                                            send_message_to_user usernick, @loc.query("help.no_command")
                                        end
                                    end
                                else
                                   send_message_to_user usernick, @loc.query("errors.no_command")
                                end
                            elsif msg[/^Repoto.*: /] != nil  && !@ignore.has?(usernick)
                                content = msg
                                content[/^Repoto.*: /] = ""
                                if Unicode.upcase(content).include?(Unicode.upcase(@loc.query("conv.keywords.name"))) && (Unicode.upcase(content).include?(Unicode.upcase(@loc.query("conv.keywords.what"))) || Unicode.upcase(content).include?(Unicode.upcase(@loc.query("conv.keywords.please"))))
                                    send_message_to_user usernick, @loc.query("conv.name")
                                elsif Unicode.upcase(content) == Unicode.upcase(@loc.query("conv.keywords.ping"))
                                    send_message_to_user usernick, "#{@loc.query("conv.pong")}."
                                elsif Unicode.upcase(content).include?(Unicode.upcase(@loc.query("conv.keywords.what2"))) && Unicode.upcase(content).include?(Unicode.upcase(@loc.query("conv.keywords.up")))
                                    send_message_to_user usernick, @loc.query("conv.whats_up")
                                elsif Unicode.upcase(content)[0..1] == Unicode.upcase(@loc.query("conv.keywords.hi")) || Unicode.upcase(content)[0..2] == Unicode.upcase(@loc.query("conv.keywords.hey"))
                                    send_message_to_user usernick, @loc.query("conv.hi")
                                elsif Unicode.upcase(content)[0..2] == Unicode.upcase(@loc.query("conv.keywords.bye"))
                                    send_message_to_user usernick, @loc.query("conv.bye")
                                elsif Unicode.upcase(content).include?(Unicode.upcase(@loc.query("conv.keywords.good"))) && Unicode.upcase(content).include?(Unicode.upcase(@loc.query("conv.keywords.bot")))
                                    send_message_to_user usernick, @loc.query("conv.good_bot")
                                elsif (Unicode.upcase(content).include?(Unicode.upcase(@loc.query("conv.keywords.bad"))) || Unicode.upcase(content).include?(Unicode.upcase(@loc.query("conv.keywords.moron"))) || Unicode.upcase(content).include?(Unicode.upcase(@loc.query("conv.keywords.useless")))) && Unicode.upcase(content).include?(Unicode.upcase(@loc.query("conv.keywords.bot")))
                                    send_message_to_user usernick, @loc.query("conv.bad_bot")
                                elsif Unicode.upcase(content) == Unicode.upcase(@loc.query("conv.keywords.wat"))
                                    send_message_to_user usernick, @loc.query("conv.wat")
                                elsif Unicode.upcase(content).include?(Unicode.upcase(@loc.query("conv.keywords.are"))) && Unicode.upcase(content).include?(Unicode.upcase(@loc.query("conv.keywords.you"))) && Unicode.upcase(content).include?(Unicode.upcase(@loc.query("conv.keywords.ok")))
                                    send_message_to_user usernick, @loc.query("conv.are_you_ok")
                                elsif Unicode.upcase(content).include?(Unicode.upcase(@loc.query("conv.keywords.prefix")))
                                    send_message_to_user usernick, @loc.query("conv.prefix") + " " + @prefix
                                else
                                    send_message_to_user usernick, @loc.query("conv.generic")
                                end
                            elsif Unicode.upcase(msg).match(/.*MAKA.?PAKA.*/) != nil && !@ignore.has?(usernick)
                                if msg.split(" ").first == "\001ACTION"
                                    msg["ACTION"] = (oper ? "[oper]" : "") + usernick
                                    msg.gsub!("\001", "")
                                    puts msg
                                    @saves.log msg
                                else
                                    puts (oper ? "[oper]" : "") + usernick + ": " + msg
                                    @saves.log (oper ? "[oper]" : "") + usernick + ": " + msg
                                end
                                if !@memo.for_user(usernick).nil? && !@memo.for_user(usernick).empty?
                                    @memo.for_user(usernick).each do |m|
                                        send_message_to_user usernick, "#{@loc.query("functions.memo.memo_from")} #{m[:from]} #{@loc.query("functions.memo.received")} #{m[:time]}: #{m[:message]}"
                                        sleep(2)
                                    end
                                    @memo.delete_user_memos usernick
                                end
                            else
                                if msg.split(" ").first == "\001ACTION"
                                    msg["ACTION"] = (oper ? "[oper]" : "") + usernick
                                    msg.gsub!("\001", "")
                                    puts msg
                                    @saves.log msg
                                else
                                    puts (oper ? "[oper]" : "") + usernick + ": " + msg
                                    @saves.log (oper ? "[oper]" : "") + usernick + ": " + msg
                                end
                            end
                        end
                        if @config[:redmine_enabled] && msg[/redmine:#[0-9]+/] != nil
                            begin
                                msg.scan(/redmine:#[0-9]+/).each do |s|
                                    nr = s.gsub("redmine:#", "").to_i
                                    idata = @redmine.issue_data nr
                                    if idata.kind_of?(Hash)
                                        send_message @loc.query("redmine.title") + " " + @loc.query("redmine.issue_url") + " " + @redmine.issue_url(nr)
                                        sleep(1)
                                        send_message @loc.query("redmine.issue_data")
                                        sleep(1)
                                        send_message @loc.query("redmine.issue_subject") + " " + idata["issue"]["subject"]
                                        sleep(1)
                                        send_message @loc.query("redmine.issue_tracker") + " " + idata["issue"]["tracker"]["name"]
                                        sleep(1)
                                        send_message @loc.query("redmine.issue_project") + " " + idata["issue"]["project"]["name"]
                                        sleep(1)
                                        send_message @loc.query("redmine.issue_author") + " " + idata["issue"]["author"]["name"]
                                        sleep(1)
                                        send_message @loc.query("redmine.issue_assignee") + " " + (idata["issue"]["assigned_to"].nil? ? @loc.query("redmine.none") : idata["issue"]["assigned_to"]["name"])
                                        sleep(1)
                                        send_message @loc.query("redmine.issue_status") + " " + idata["issue"]["status"]["name"]
                                        sleep(1)
                                        send_message @loc.query("redmine.issue_done") + " " + idata["issue"]["done_ratio"].to_s
                                        sleep(1)
                                    else
                                        send_message @loc.query("redmine.query_error") + " " + idata
                                    end
                                end
                            rescue => e
                                send_message @loc.query("redmine.query_error") + " " + e.to_s
                            end
                        end
                    rescue Exception => e
                        if e.to_s.include?("UTF-8")
                            puts "UTF-8 exception caught!"
                            send_message @loc.query("misc.utf8")
                        else
                            raise e
                        end
                    end
                end
                @conn.close
            rescue Exception => e
                puts "Caught exception: " + e.to_s
                puts "Backtrace: " + e.backtrace.join("\n")
                puts "Closing connection..."
                @conn.close
                puts "Dumping seen data..."
                @seen.dump
                puts "Dumping memo data..."
                @memo.dump
                puts "Dumping reminders..."
                @reminder.dump
                puts "Dumping ignores..."
                @ignore.dump
                puts "Exiting..."
            end
        end

        def connect
            @conn = TCPSocket.new @server, @port
            puts "NICK #{@nick}#{!@suffix.nil? ? "|#{@suffix}" : ""}"
            dlog_bot "NICK #{@nick}#{!@suffix.nil? ? "|#{@suffix}" : ""}"
            @conn.puts "NICK #{@nick}#{!@suffix.nil? ? "|#{@suffix}" : ""}"
            puts "USER #{!@suffix.nil? ? "#{@suffix.downcase}" : ""}-#{@nick.downcase} 8 * :#{@nick}"
            dlog_bot "USER #{!@suffix.nil? ? "#{@suffix.downcase}" : ""}-#{@nick.downcase} 8 * :#{@nick}"
            @conn.puts "USER #{!@suffix.nil? ? "#{@suffix.downcase}" : ""}-#{@nick.downcase} 8 * :#{@nick}"
            puts "CAP REQ identify-msg"
            dlog_bot "CAP REQ identify-msg"
            @conn.puts "CAP REQ identify-msg"
            puts "CAP END"
            dlog_bot "CAP END"
            @conn.puts "CAP END"
        end

        def join_channel
            puts "JOIN :#{@channel}"
            dlog_bot "JOIN :#{@channel}"
            @conn.puts "JOIN :#{@channel}"
        end

        def send_nickserv_check
            puts "PRIVMSG NickServ help"
            dlog_bot "PRIVMSG NickServ help"
            @conn.puts "PRIVMSG NickServ help"
        end

        def send_message msg
            dlog_bot "PRIVMSG #{@channel} :#{msg}"
            @conn.puts "PRIVMSG #{@channel} :#{msg}"
        end

        def send_message_to_user user, msg
            send_message "#{user}: #{msg}"
        end

        def perform_action msg
            send_message "\001ACTION #{msg}\001"
        end

        def dlog_server msg
            if @config[:debug_log_enabled]
                @dlog.puts "[" + Time.now.to_s + "] SERVER: " + msg
            end
        end

        def dlog_bot msg
            if @config[:debug_log_enabled]
                @dlog.puts "[" + Time.now.to_s + "] BOT: " + msg
            end
        end
    end
end
