require 'socket'
require 'yaml'
require 'fileutils'
require 'net/http'
require 'json'
require 'simplelion-ruby'
require 'unicode'
require_relative 'seen'
require_relative 'memo'

module Repoto
    class Bot
        def initialize
            if File.exists?("config.yml")
                @config = YAML.load_file("config.yml")
            else
                raise "Could not read config!"
            end
            if File.exists?("dynconfig.yml")
                @dynconfig = YAML.load_file("dynconfig.yml")
            else
                @dynconfig = {}
            end
            @channel = "#" + @config[:channel]
            @nick = "Repoto"
            @suffix = @config[:suffix]
            @version = "0.8"
            @creator = "Phitherek_"
            @server = @config[:server]
            @port = @config[:port].to_i
            @loc = SimpleLion::Localization.new("locales", @dynconfig[:locale])
            @imsg_enabled = false
            @seen = Repoto::Seen.new
            @memo = Repoto::Memo.new
            
            puts "Connecting..."
            
            connect
            begin
                while line = @conn.gets
                    oper = false
                    auth = false
                    line.force_encoding 'utf-8'
                    #puts "SERVER: " + line
                    la = line.split(" ")
                    if la[0] == "PING"
                        puts "Ping-pong..."
                        @conn.puts "PONG #{la[1]}"
                    end
                    if la[0][0] == ":"
                        if la[1] == "CAP" && la[2] == "#{@nick}#{!@suffix.nil? ? "|#{@suffix}" : ""}" && la[3] == "ACK" && la[4] == ":identify-msg"
                            @imsg_enabled = true
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
                    if la[1] == "JOIN"
                        puts "*** #{usernick} has joined the channel."
                        @seen.update usernick, :join
                        next
                    elsif la[1] == "PART" || la[1] == "QUIT"
                        puts "*** #{usernick} has left the channel."
                        @seen.update usernick, :part
                        next
                    elsif la[1] != "PRIVMSG"
                        next
                    else
                        @seen.update usernick, :join
                    end
                    if @seen.find(usernick) == :now && !@memo.for_user(usernick).nil? && !@memo.for_user(usernick).empty?
                        @memo.for_user(usernick).each do |m|
                            send_message_to_user usernick, "#{@loc.query("functions.memo.memo_from")} #{m[:from]} #{@loc.query("functions.memo.received")} #{m[:time]}: #{m[:message]}"
                            sleep(2)
                        end
                        @memo.delete_user_memos usernick
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
                        end
                        if msg.nil? || msg.empty?
                            next
                        end
                        if msg[0] == "^" && msg[1] != "^" && msg[1] != "_" && msg[1] != " " && msg[1] != "\n" && msg[1] != nil
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
                                        send_message_to_user usernick, "#{@loc.query("usage")} ^addop user_nick"
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
                                    send_message_to_user usernick, "#{@loc.query("usage")} ac #{@loc.query("functions.ac.command_name")} #{@loc.query("functions.ac.command_output")}"
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
                                    send_message_to_user usernick, "#{@loc.query "usage"} rc #{@loc.query("functions.rc.command_name")}"
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
                                        data = JSON.parse(data)
                                        send_message_to_user usernick, "#{@loc.query("functions.whois.in_hs")} #{data["total_devices_count"]} #{data["total_devices_count"].to_s.length == 1 ? (data["total_devices_count"].to_i == 0 ? @loc.query("functions.whois.devices0") : (data["total_devices_count"].to_i == 1 ? @loc.query("functions.whois.devices1") : ((data["total_devices_count"].to_i > 1 && data["total_devices_count"].to_i < 5) ? (@loc.query("functions.whois.devices24")) : (@loc.query("functions.whois.devices59"))))) : (data["total_devices_count"].to_s[-2].to_i == 1 ? (@loc.query("functions.whois.devices1019")) : ((data["total_devices_count"].to_s[-1].to_i > 1 && data["total_devices_count"].to_s[-1].to_i < 5) ? @loc.query("functions.whois.devices24") : @loc.query("functions.whois.devices59")))}, #{data["unknown_devices_count"]} #{data["unknown_devices_count"].to_s.length == 1 ? (data["unknown_devices_count"].to_i == 0 ? @loc.query("functions.whois.unknown0") : (data["unknown_devices_count"].to_i == 1 ? @loc.query("functions.whois.unknown1") : ((data["unknown_devices_count"].to_i > 1 && data["unknown_devices_count"].to_i < 5) ? (@loc.query("functions.whois.unknown24")) : (@loc.query("functions.whois.unknown59"))))) : (data["unknown_devices_count"].to_s[-2].to_i == 1 ? (@loc.query("functions.whois.unknown1019")) : ((data["unknown_devices_count"].to_s[-1].to_i > 1 && data["unknown_devices_count"].to_s[-1].to_i < 5) ? @loc.query("functions.whois.unknown24") : @loc.query("functions.whois.unknown59")))}. #{data["users"].empty? ? @loc.query("functions.whois.no_users") : @loc.query("functions.whois.users")} #{data["users"].join(", ")}"
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
                                        data = JSON.parse(data)
                                        data = data["sensors"]
                                        data = data["temperature"]
                                        msg = @loc.query("functions.temp") + " "
                                        data.each do |d|
                                            msg += "#{d["location"]}: #{d["value"]} #{d["unit"]}"
                                            msg += ", " unless d == data.last
                                        end
                                        send_message_to_user usernick, msg
                                    else
                                         send_message_to_user usernick, @loc.query("errors.connection")
                                    end
                                else
                                    send_message_to_user usernick, @loc.query("errors.no_command")
                                end
                            when "light"
                                if @dynconfig[:hskrk] == "on"
                                    data = Net::HTTP.get("spaceapi.hskrk.pl", "/")
                                    if !data.nil?
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
                                        send_message_to_user usernick, "Usage: ^locale locale_to_switch_to"
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
                            when "restart"
                                if oper
                                    send_message_to_user usernick, @loc.query("functions.restart.channel")
                                    @conn.puts "QUIT :#{@loc.query("functions.restart.quit")}"
                                    @conn.close
                                    sleep 5
                                    if File.exists?("config.yml")
                                        @config = YAML.load_file("config.yml")
                                    else
                                        raise "Could not read config!"
                                    end
                                    if File.exists?("dynconfig.yml")
                                        @dynconfig = YAML.load_file("dynconfig.yml")
                                    else
                                        @dynconfig = {}
                                    end
                                    @loc = SimpleLion::Localization.new("locales", @dynconfig[:locale])
                                    connect
                                else
                                    send_message_to_user usernick, @loc.query("errors.not_authorized")
                                end
                            when "help"
                                if cmd[1].nil?
                                    send_message_to_user usernick, "#{@loc.query("help.available_commands")} ^version, ^creator, ^operators, ^addop,#{@dynconfig[:hskrk] == "on" ? " ^whois, ^temp, ^light," : ""} ^ac, ^lc, ^rc, ^c, ^cu, ^cd, ^cr, ^dumpdyn, ^ping, ^poke, ^kick, ^locales, ^locale, ^seen, ^memo, ^help, ^restart, ^exit"
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
                                    else
                                        send_message_to_user usernick, @loc.query("help.no_command")
                                    end
                                end
                            else                                          
                               send_message_to_user usernick, @loc.query("errors.no_command")
                            end
                        elsif msg[0..6] == "Repoto:"
                            content = msg[8..-1]
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
                                send_message_to_user usernick, @loc.query("conv.prefix")
                            else
                                send_message_to_user usernick, @loc.query("conv.generic")
                            end
                        elsif @dynconfig[:hskrk] == "on" && @dynconfig[:mp] == "on" && Unicode.upcase(msg).include?("MAKA") && Unicode.upcase(msg).include?("PAKA")
                            if msg.split(" ").first == "\001ACTION"
                                msg["ACTION"] = (oper ? "[oper]" : "") + usernick
                                puts msg
                            else
                                puts (oper ? "[oper]" : "") + usernick + ": " + msg
                            end
                            send_message "maka paka "*Random.new.rand(10..30)
                        else
                            if msg.split(" ").first == "\001ACTION"
                                msg["ACTION"] = (oper ? "[oper]" : "") + usernick
                                puts msg
                            else
                                puts (oper ? "[oper]" : "") + usernick + ": " + msg
                            end
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
                puts "Exiting..."
            end
        end
        
        def connect
            @conn = TCPSocket.new @server, @port
            puts "NICK #{@nick}#{!@suffix.nil? ? "|#{@suffix}" : ""}"
            @conn.puts "NICK #{@nick}#{!@suffix.nil? ? "|#{@suffix}" : ""}"
            puts "USER #{@nick.downcase}#{!@suffix.nil? ? "-#{@suffix.downcase}" : ""} 8 * :#{@nick}"
            @conn.puts "USER #{@nick.downcase}#{!@suffix.nil? ? "-#{@suffix.downcase}" : ""} 8 * :#{@nick}"
            puts "CAP REQ identify-msg"
            @conn.puts "CAP REQ identify-msg"
            puts "CAP END"
            @conn.puts "CAP END"
            puts "JOIN :#{@channel}"
            @conn.puts "JOIN :#{@channel}"
        end
        
        def send_message msg
            @conn.puts "PRIVMSG #{@channel} :#{msg}"
        end
        
        def send_message_to_user user, msg
            send_message "#{user}: #{msg}"
        end
        
        def perform_action msg
            send_message "\001ACTION #{msg}\001"
        end
    end
end
