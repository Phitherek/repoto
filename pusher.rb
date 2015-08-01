require 'pusher'

module Repoto
    class Pusher
        def self.init(url, event)
            @@url = url
            ::Pusher.url = @@url
            @@event = event
        end

        def self.push channel, msg
            if channel.to_s != 'test_channel'
                channel = 'private-' + channel.to_s
            end
            ::Pusher[channel.to_s].trigger(@@event, {message: msg})
        end
    end
end