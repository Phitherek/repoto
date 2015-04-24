require_relative 'connection'
require_relative 'ircline'
require_relative 'ircmessage'
require_relative 'microphone'
require_relative 'speaker'
require_relative 'config'
require 'singleton'
module Repoto
    class SpecialModes
        include Singleton

        def initialize
            @lastcheck = nil
            @thr = nil
            @operator = false
            @voiced = false
            reload
        end

        def reload
            @thr = Thread.new do
                while true
                    if @lastcheck.nil? || Time.now-@lastcheck >= 60
                        @lastcheck = Time.now
                        Speaker.instance.enqueue IRCMessage.new("WHOIS #{Config.instance.full_nick}", nil, :raw)
                        line = Microphone.instance.peek
                        i = 0
                        while (line.nil? || line.type != :whois_channels) && i < 15
                            sleep 1
                            line = Microphone.instance.peek
                            i = i+1
                        end
                        if !line.nil? && line.type == :whois_channels
                            line = Microphone.instance.pop
                        end
                        if !line.nil? && line.type == :whois_channels && line.target == "#{Config.instance.full_nick}"
                            channels = line.whois_channels.split(" ")
                            channels.each do |channel|
                                op = false
                                v = false
                                if channel[0] == "@"
                                    op = true
                                    channel = channel[1..-1]
                                end
                                if channel[0] == "+"
                                    v = true
                                    channel = channel[1..-1]
                                end
                                if channel == Config.instance.formatted_channel
                                    @operator = op
                                    @voiced = v
                                    break
                                end
                            end
                        end
                    end
                    sleep 5
                end
            end
        end

        def operator?
            @operator
        end

        def voiced?
            @voiced
        end

        def stop
            @thr.kill
        end
    end
end