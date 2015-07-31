require 'pusher'

module Repoto
    class Pusher
        def self.init(url, event)
            @@url = url
            ::Pusher.url = @@url
            @@event = event
        end

        def self.push channel, msg
            ::Pusher[channel.to_s].trigger(@@event, {message: msg})
        end
    end
end