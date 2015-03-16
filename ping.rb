require 'singleton'
require_relative 'microphone'
require_relative 'speaker'
require_relative 'alias'
require_relative 'dynconfig'
require_relative 'seen'
require_relative 'memo'
require_relative 'reminder'
require_relative 'ignore'
require_relative 'connection'
module Repoto
    class Ping
        include Singleton
        def initialize
            reload
        end

        def reload
            @last_ping = Time.now
            @thr = Thread.new do
                while true
                    begin
                        if !Microphone.instance.peek.nil?
                            if !Microphone.instance.peek.nil? && Microphone.instance.peek.type == :ping
                                line = Microphone.instance.pop
                                Speaker.instance.enqueue IRCMessage.new("PONG #{line.broken_line[1]}", nil, :raw)
                            end
                            @last_ping = Time.now
                        end
                        if Time.now - @last_ping > 600
                            puts "Ping timeout - restarting..."
                            Microphone.instance.mute
                            Speaker.instance.mute
                            DynConfig.instance.dump
                            Seen.instance.dump
                            Memo.instance.dump
                            Reminder.instance.dump
                            Ignore.instance.dump
                            Alias.instance.dump
                            Connection.instance.reconnect
                            Alias.instance.reload
                            Ignore.instance.reload
                            Reminder.instance.reload
                            Memo.instance.reload
                            Seen.instance.reload
                            Dynconfig.instance.reload
                            Speaker.instance.unmute
                            Microphone.instance.unmute
                            @last_ping = Time.now
                        end
                        sleep 0.01
                    rescue Exception => e
                        if e.to_s.include?("UTF-8")
                            puts "UTF-8 exception caught!"
                            next
                        elsif (e.to_s.include?("type") || e.to_s.include?("usernick")) && e.to_s.include?("nil")
                            puts "Nil line exception caught!"
                            next
                        else
                            raise e
                        end
                    end
                end
            end
        end

        def stop
            @thr.kill
        end
    end
end