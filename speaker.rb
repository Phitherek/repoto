require 'singleton'
require_relative 'connection'
require_relative 'irctranslator'
require_relative 'config'
module Repoto
    class Speaker
        include Singleton
        def initialize
            @queue = []
            unmute
        end

        def enqueue msg
            if msg.kind_of?(IRCMessage)
                @queue.unshift(msg)
            end
        end

        def join
            puts "JOIN :" + Repoto::Config.instance.formatted_channel
            enqueue IRCMessage.new("JOIN :" + Repoto::Config.instance.formatted_channel, nil, :raw)
        end

        def mute
            @thr.kill
        end

        def unmute
            @thr = Thread.new do
                @conn = Connection.instance
                while true
                    msg = @queue.pop
                    if !msg.nil?
                        @conn.send IRCTranslator.to_irc(msg)
                    end
                    sleep 2
                end
            end
        end

        def empty?
            @queue.empty?
        end

    end
end