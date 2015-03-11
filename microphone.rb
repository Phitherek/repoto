require 'singleton'
require_relative 'connection'
require_relative 'irctranslator'
require_relative 'ignore'
module Repoto
    class Microphone
        include Singleton
        def initialize
            @queue = []
            unmute
        end

        def unmute
            @thr = Thread.new do
                @conn = Connection.instance
                while true
                    begin
                        line = @conn.recv
                        @queue.unshift(IRCTranslator.from_irc(line))
                        sleep 0.01
                    rescue => e
                        raise e
                    end
                end
            end
        end

        def mute
            @thr.kill
        end

        def peek
            return @queue.last if !@queue.last.nil? && !Ignore.instance.has?(@queue.last.usernick)
            nil
        end

        def pop
            return @queue.pop if !@queue.last.nil? && !Ignore.instance.has?(@queue.last.usernick)
            @queue.pop
            nil
        end
    end
end