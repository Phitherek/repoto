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
            while true
                if !@mic.peek.nil?
                    if @mic.peek.type == :firstline
                        @mic.pop
                        @speaker.join
                        @sauth.detect
                        sleep 5
                        @sauth.run
                    elsif ![:ncerror, :cap].include?(@mic.peek.type)
                        @mic.pop
                    end
                end
                sleep 0.01
            end
        end
    end
end
