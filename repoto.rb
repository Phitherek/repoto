require 'socket'
require 'yaml'
require 'fileutils'
require 'net/http'
require 'json'

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
            @version = "0.4.1"
            @creator = "Phitherek_"
            @server = @config[:server]
            @port = @config[:port].to_i
            @imsg_enabled = false
            
            puts "Connecting..."
            
            connect
            
            while line = @conn.gets
                oper = false
                auth = false
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
                if la[2] == @channel
                    #puts "Message is for the channel"
                else
                    #puts "Skipping parse"
                    next
                end
                msg = la[3..-1].join(" ") if !la[3].nil?
                if msg.nil?
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
                    if msg[0] == "^" && msg[1] != "^" && msg[1] != "_" && msg[1] != " " && msg[1] != "\n" && msg[1] != nil
                        cmd = msg[1..-1]
                        cmd = cmd.split(" ")
                        case cmd[0]
                        when "version"
                            send_message_to_user usernick, "My version is #{@version}"
                        when "creator"
                            send_message_to_user usernick, "I have been created by #{@creator}"
                        when "operators"
                            send_message_to_user usernick, "My operators are: #{@dynconfig[:operators].join(" ")}"
                        when "exit"
                            if oper
                                send_message_to_user usernick, "Bye!"
                                @conn.puts "QUIT :Exiting on operator' s request..."
                                break
                            else
                                send_message_to_user usernick, "You are not authorized!"
                            end
                        when "poke"
                            if cmd[1].nil?
                                send_message_to_user usernick, "Who to poke?"
                            else
                                perform_action "pokes #{cmd[1]} on #{usernick}' s request"
                            end
                        when "kick"
                            if cmd[1].nil?
                                send_message_to_user usernick, "Who to kick?"
                            else
                                perform_action "kicks #{cmd[1]} on #{usernick}' s request"
                            end
                        when "ping"
                            if cmd[1].nil?
                                send_message_to_user usernick, "Who to ping?"
                            else
                                send_message_to_user cmd[1], "Ping from #{usernick}."
                            end
                        when "addop"
                            if oper
                                if !cmd[1].nil?
                                    @dynconfig[:operators] << cmd[1]
                                    send_message_to_user cmd[1], "#{usernick} has just made you an operator!"
                                else
                                    send_message_to_user usernick, "Usage: ^addop user_nick"
                                end
                            else
                                send_message_to_user usernick, "You are not authorized!"
                            end
                        when "dumpdyn"
                            if oper
                                FileUtils.rm("dynconfig.yml")
                                File.open("dynconfig.yml", "w") do |f|
                                    f << YAML.dump(@dynconfig)
                                end
                                send_message_to_user usernick, "Dynamic config saved!"
                            else
                                send_message_to_user usernick, "You are not authorized!"
                            end
                        when "lc"
                            if !@dynconfig[:c].nil?
                                send_message_to_user usernick, "Custom commands: " + @dynconfig[:c].keys.join(" ").to_s
                            else
                                send_message_to_user usernick, "No custom commands yet!"
                            end
                        when "ac"
                            if !cmd[1].nil? && !cmd[2].nil?
                                @dynconfig[:c] ||= {}
                                @dynconfig[:c][cmd[1].to_sym] = cmd[2..-1].join(" ").to_s
                                send_message_to_user usernick, "Custom command created!"
                            else
                                send_message_to_user usernick, "Usage: ac command_name command_output"
                            end
                        when "rc"
                            if !cmd[1].nil?
                                if !@dynconfig[:c].nil? && !@dynconfig[:c][cmd[1].to_sym].nil?
                                    @dynconfig[:c].delete(cmd[1].to_sym)
                                    send_message_to_user usernick, "Custom command removed!"
                                else
                                    send_message_to_user usernick, "Could not find command!"
                                end
                            else
                                send_message_to_user usernick, "Usage: rc command_name"
                            end
                        when "c"
                            if !cmd[1].nil?
                                if !@dynconfig[:c].nil? && !@dynconfig[:c][cmd[1].to_sym].nil?
                                    send_message @dynconfig[:c][cmd[1].to_sym].to_s
                                else
                                    send_message_to_user usernick, "Could not find this command, sorry..."
                                end
                            else
                                send_message_to_user usernick, "Which command?"
                            end
                        when "enablehskrk"
                            if oper
                                @dynconfig[:hskrk] = "on"
                                send_message_to_user usernick, "Hackerspace Kraków specific functions enabled!"
                            else
                                send_message_to_user usernick, "You are not authorized!"
                            end
                        when "disablehskrk"
                            if oper
                                @dynconfig[:hskrk] = "off"
                                send_message_to_user usernick, "Hackerspace Kraków specific functions disabled!"
                            else
                                send_message_to_user usernick, "You are not authorized!"
                            end
                        when "whois"
                            if @dynconfig[:hskrk] == "on"
                                data = Net::HTTP.get("whois.hskrk.pl", "/whois")
                                data = JSON.parse(data)
                                send_message_to_user usernick, "In HS: #{data["total_devices_count"]} devices, #{data["unknown_devices_count"]} unknown. Users: #{data["users"].join(", ")}"
                            else
                                send_message_to_user usernick, "I do not know this command!"
                            end
                        when "restart"
                            if oper
                                send_message_to_user usernick, "... restarting ..."
                                @conn.puts "QUIT :Exiting on operator' s request..."
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
                                connect
                            else
                                send_message_to_user usernick, "You are not authorized!"
                            end
                        when "help"
                            if cmd[1].nil?
                                send_message_to_user usernick, "Available commands: ^version, ^creator, ^operators, ^addop,#{@dynconfig[:hskrk] == "on" ? "^whois, " : ""} ^ac, ^lc, ^rc, ^c, ^dumpdyn, ^ping, ^poke, ^kick, ^help, ^restart, ^exit"
                            else
                                case cmd[1]
                                when "version"
                                    send_message_to_user usernick, "I will print out my version."
                                when "creator"
                                    send_message_to_user usernick, "You will know who created me."
                                when "operators"
                                    send_message_to_user usernick, "You will know all of my operators."
                                when "poke"
                                    send_message_to_user usernick, "I will poke a user... but tell him that was your request."
                                when "ping"
                                    send_message_to_user usernick, "I will ping a user... but tell him that was your request."
                                when "kick"
                                    send_message_to_user usernick, "I will kick a user... but tell him that was your request."
                                when "ac"
                                    send_message_to_user usernick, "I will add a custom command."
                                when "lc"
                                    send_message_to_user usernick, "I will list custom commands."
                                when "c"
                                    send_message_to_user usernick, "I will execute a custom command."
                                when "rc"
                                    send_message_to_user usernick, "I will remove a custom command."
                                when "whois"
                                    if @dynconfig[:hskrk] == "on"
                                        send_message_to_user usernick, "I will show you who is in Hackerspace Kraków."
                                    else
                                        send_message_to_user usernick, "I do not know how to do this..."
                                    end
                                when "exit"
                                    if oper
                                        send_message_to_user usernick, "I will end my existence... for now."
                                    else
                                        send_message_to_user usernick, "I will not tell you, this is only for my operators."
                                    end
                                when "restart"
                                    if oper
                                        send_message_to_user usernick, "I will end my existence and then live again."
                                    else
                                        send_message_to_user usernick, "I will not tell you, this is only for my operators."
                                    end
                                when "addop"
                                    if oper
                                        send_message_to_user usernick, "I will add an operator"
                                    else
                                        send_message_to_user usernick, "I will not tell you, this is only for my operators."
                                    end
                                when "dumpdyn"
                                    if oper
                                        send_message_to_user usernick, "I will permanently save dynamic config"
                                    else
                                        send_message_to_user usernick, "I will not tell you, this is only for my operators."
                                    end
                                else
                                    send_message_to_user usernick, "I do not know how to do this..."
                                end
                            end
                        else                                          
                           send_message_to_user usernick, "I do not know this command!"
                        end
                    elsif msg[0..6] == "Repoto:"
                        content = msg[8..-1]
                        if content.upcase.include?("NAME") && (content.upcase.include?("WHAT") || content.upcase.include?("PLEASE"))
                            send_message_to_user usernick, "My name is Repoto. Nice to meet you."
                        elsif content.upcase == "PING"
                            send_message_to_user usernick, "Pong."
                        elsif content.upcase.include?("WHAT") && content.upcase.include?("UP")
                            send_message_to_user usernick, "Everything' s fine, thank you."
                        elsif content.upcase[0..1] == "HI" || content.upcase[0..2] == "HEY"
                            send_message_to_user usernick, "Hi, what' s up?"
                        elsif content.upcase[0..2] == "BYE"
                            send_message_to_user usernick, "Bye."
                        elsif content.upcase.include?("GOOD") && content.upcase.include?("BOT")
                            send_message_to_user usernick, "Always at your service ;)"   
                        elsif (content.upcase.include?("BAD") || content.upcase.include?("MORON") || content.upcase.include?("USELESS")) && content.upcase.include?("BOT")
                            send_message_to_user usernick, "I was programmed that way :("
                        elsif content.upcase == "WAT?"
                            send_message_to_user usernick, "Well, that' s how it is..."
                        elsif content.upcase.include?("ARE") && content.upcase.include?("YOU") && content.upcase.include?("OK")
                            send_message_to_user usernick, "Yes, I' m fine."
                        elsif content.upcase.include?("PREFIX")
                            send_message_to_user usernick, "My command prefix is ^"
                        else
                            send_message_to_user usernick, "What?"
                        end
                    else
                        puts (oper ? "[oper]" : "") + usernick + ": " + msg
                    end
                end
            end
            @conn.close
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
