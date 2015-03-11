require 'socket'
require 'yaml'
require 'fileutils'
require 'net/http'
require 'json'
require 'simplelion-ruby'
require 'unicode'
require 'time'
require_relative 'config'
require_relative 'dynconfig'
require_relative 'servicesauth'
require_relative 'debuglog'
require_relative 'seen'
require_relative 'memo'
require_relative 'saves'
require_relative 'reminder'
require_relative 'ignore'
require_relative 'microphone'
require_relative 'speaker'
require_relative 'localization'
require_relative 'alias'
require_relative 'connection'
require_relative 'ping'
require_relative 'functions'
require_relative 'conv'
require_relative 'extras'

module Repoto
    class Bot
        def initialize
            Thread.abort_on_exception = true
            @config = Repoto::Config.instance
            @dynconfig = Repoto::DynConfig.instance
            @sauth = Repoto::ServicesAuth.instance
            @loc = Repoto::Localization.instance
            @seen = Repoto::Seen.instance
            @memo = Repoto::Memo.instance
            @saves = Repoto::Saves.instance
            @reminder = Repoto::Reminder.instance
            @ignore = Repoto::Ignore.instance
            @dlog = Repoto::DebugLog.instance
            @mic = Repoto::Microphone.instance
            @speaker = Repoto::Speaker.instance
            @alias = Repoto::Alias.instance
            @ping = Repoto::Ping.instance
            while true
                if !@mic.peek.nil?
                    oper = false
                    if !@mic.peek.usernick.nil? && @dynconfig.operators.include?(@mic.peek.usernick) && @sauth.status(@mic.peek.usernick) == :logged_in
                        oper = true
                    end
                    if @mic.peek.type == :firstline
                        @mic.pop
                        @speaker.join
                        @sauth.detect
                        sleep 5
                        @sauth.run
                    elsif @mic.peek.type == :join
                        line = @mic.pop
                        puts "*** #{line.usernick} has joined the channel"
                        @saves.log "*** #{line.usernick} has joined the channnel"
                        @seen.update line.usernick, :join
                        @seen.update @alias.lookup(line.usernick), :join
                        # This part is MOST essential
                        if @alias.lookup(line.usernick) == "R__"
                            @speaker.enqueue IRCMessage.new(["Ohai :3", "Hi! ;)", "Hej! :)", "o/", "Haaaaaai :3"].shuffle(random: Random.new(Time.now.to_f.to_i)).first, line.usernick, :channel)
                        # This part is rather essential
                        elsif @alias.lookup(line.usernick) == "Phitherek_"
                            @speaker.enqueue IRCMessage.new(["Witaj", "Cześć", "Hej", "o/", "Maka paka!"].shuffle(random: Random.new(Time.now.to_f.to_i)).first, line.usernick, :channel)
                        end
                    elsif @mic.peek.type == :part || @mic.peek.type == :quit
                        line = @mic.pop
                        puts "*** #{line.usernick} has left the channel"
                        @saves.log "*** #{line.usernick} has left the channel"
                        @seen.update line.usernick, :part
                        @seen.update @alias.lookup(line.usernick), :part
                    elsif @mic.peek.type == :kick
                        line = @mic.pop
                        puts "*** #{line.target} has been kicked from the channel by #{line.usernick}"
                        @saves.log "*** #{line.target} has been kicked from the channel by #{line.usernick}"
                        @seen.update line.target, :part
                        @seen.update @alias.lookup(line.target), :part
                        if line.target == @config.full_nick
                            sleep 5
                            @speaker.join
                        end
                    elsif @mic.peek.type == :error
                        @mic.pop
                        puts "Server error - restarting"
                        restart
                    elsif @mic.peek.type == :privmsg
                        line = @mic.pop
                        puts "#{(line.target == @config.formatted_channel) ? "" : "[priv]"}#{oper ? "[oper]" : ""}#{line.usernick}: #{line.formatted_message}"
                        @seen.update line.usernick, :join
                        @seen.update @alias.lookup(line.usernick), :join
                        if !Repoto::Functions.parse line
                            if !Repoto::Conv.parse line
                                Repoto::Extras.parse line
                            end
                        end
                    elsif ![:ncerror, :cap, :ping].include?(@mic.peek.type)
                        @mic.pop
                    end
                end
                sleep 0.01
            end
        end

        def restart
            @mic.mute
            @speaker.mute
            @ping.stop
            @dynconfig.dump
            @seen.dump
            @memo.dump
            @reminder.dump
            @ignore.dump
            @alias.dump
            Connection.instance.reconnect
            @alias.reload
            @ignore.reload
            @reminder.reload
            @memo.reload
            @seen.reload
            @dynconfig.reload
            @ping.reload
            @speaker.unmute
            @mic.unmute
        end

        def stop
            @mic.mute
            @speaker.mute
            @ping.stop
            @dynconfig.dump
            @seen.dump
            @memo.dump
            @reminder.dump
            @ignore.dump
            @alias.dump
            Connection.instance.close
        end
    end
end
