require 'singleton'
require_relative 'ircmessage'
require_relative 'speaker'
require_relative 'microphone'
require_relative 'config'

module Repoto
    class ServicesAuth
        include Singleton

        def initialize
            @imsg_enabled = false
            @nickserv_present = true
            @users = {}
        end

        def run
            if method != :none
                Thread.new do |t|
                    while true
                        @users.each_key do |u|
                            if Time.now - @users[u][:time] > 600
                                @users[u] = nil
                            end
                        end
                        line = Microphone.instance.peek
                        if !line.nil? && line.type == :privmsg
                            check = false
                            if @users[line.usernick] == nil
                                check = true
                            else
                                if Time.now-@users[line.usernick][:time] > 600
                                    check = true
                                end
                            end
                            if check
                                if method == :imsg
                                    if line.message[0][0] == "+"
                                        @users[line.usernick] ||= {}
                                        @users[line.usernick][:status] = "3"
                                        @users[line.usernick][:time] = Time.now
                                    else
                                        @users[line.usernick] ||= {}
                                        @users[line.usernick][:status] = "1"
                                        @users[line.usernick][:time] = Time.now
                                    end
                                    puts @users
                                elsif method == :acc
                                    Speaker.instance.enqueue IRCMessage.new("ACC #{line.usernick}", "NickServ", :privmsg)
                                end
                            end
                        elsif !line.nil? && line.type == :notice
                            if line.broken_line[2] == Repoto::Config.instance.full_nick
                                if line.broken_line[4] == "ACC"
                                    nick = line.broken_line[3][1..-1]
                                    @users[nick] ||= {}
                                    @users[nick][:status] = line.broken_line[5]
                                    @users[nick][:time] = Time.now
                                end
                            end
                        end
                        sleep 0.01
                    end
                end
            end
            false
        end

        def status nick
            if !@users[nick].nil?
                case @users[nick][:status]
                when "3"
                    return :logged_in
                when "2"
                    return :not_logged_in_recognized
                when "1"
                    return :exists_not_logged_in
                else
                    return :does_not_exist
                end
            end
            :does_not_exist
        end

        def method
            if @imsg_enabled
                :imsg
            elsif @nickserv_present
                :acc
            else
                :none
            end
        end

        def enable_imsg!
            @imsg_enabled = true
        end

        def disable_imsg!
            @imsg_enabled = false
        end

        def disable_nickserv!
            @nickserv_present = false
        end

        def enable_nickserv!
            @nickserv_present = true
        end

        def detect
            Thread.new do
                puts "CAP REQ identify-msg"
                Speaker.instance.enqueue IRCMessage.new("CAP REQ identify-msg", nil, :raw)
                puts "CAP END"
                Speaker.instance.enqueue IRCMessage.new("CAP END", nil, :raw)
                th = Thread.new do
                    while true
                        if !Microphone.instance.peek.nil? && Microphone.instance.peek.type == :cap
                            line = Microphone.instance.pop
                            puts line.broken_line.join(" ")
                            if line.broken_line[2] == Repoto::Config.instance.full_nick && line.broken_line[4] == ":identify-msg"
                                if line.broken_line[3] == "ACK"
                                    enable_imsg!
                                elsif line.broken_line[3] == "NAK"
                                    disable_imsg!
                                end
                                break
                            end
                        end
                        sleep 0.01
                    end
                end
                th.join
                if method == :imsg
                    Thread.current.kill
                else
                    puts "PRIVMSG NickServ help"
                    Speaker.instance.enqueue IRCMessage.new("help", "NickServ", :privmsg)
                    Thread.new do |t|
                        start_time = Time.now
                        while Time.now - start_time <= 5
                            if Microphone.instance.peek.type == :ncerror
                                if Microphone.instance.peek.broken_line[1] == "401" && Microphone.instance.peek.broken_line[3] == "NickServ"
                                    disable_nickserv!
                                    Microphone.instance.pop
                                elsif Microphone.instance.peek.broken_line[1] == "433"
                                    raise "Nickname already in use!"
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end