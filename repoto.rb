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
require_relative 'redmine'
require_relative 'github'
require_relative 'graphite'
require_relative 'ignore'
require_relative 'microphone'
require_relative 'speaker'
require_relative 'localization'
require_relative 'alias'
require_relative 'connection'

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
                    elsif @mic.peek.type == :part || @mic.peek.type == :quit
                        line = @mic.pop
                        if line.usernick == @config.full_nick && Unicode.upcase(line.message).include?("PING TIMEOUT")
                            puts "Ping timeout - restarting..."
                            @mic.mute
                            @speaker.mute
                            @dynconfig.dump
                            @seen.dump
                            @memo.dump
                            @reminder.dump
                            @ignore.dump
                            @alias.dump
                            Repoto::Connection.instance.reconnect
                            @alias.reload
                            @ignore.reload
                            @reminder.reload
                            @memo.reload
                            @seen.reload
                            @dynconfig.reload
                            @speaker.unmute
                            @mic.unmute
                        else
                            puts "*** #{line.usernick} has left the channel"
                            @saves.log "*** #{line.usernick} has left the channel"
                            @seen.update line.usernick, :part
                            @seen.update @alias.lookup(line.usernick), :part
                        end
                    elsif ![:ncerror, :cap].include?(@mic.peek.type)
                        @mic.pop
                    end
                end
                sleep 0.01
            end
        end
    end
end
