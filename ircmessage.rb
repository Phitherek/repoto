module Repoto
    class IRCMessage
        def initialize content, target = nil, type = :channel, action = false
            @content = content.to_s
            @target = (target.nil? || (target.kind_of?(Symbol) && target == :action) || target.kind_of?(String)) ? target : nil
            @type = [:channel, :privmsg, :raw].include?(type) ? type : :channel
            @action = action
        end

        def content
            @content
        end

        def target
            @target
        end

        def type
            @type
        end

        def action?
            @action
        end

        def content= val
            @content = val.to_s
        end

        def target= val
            @target = (val.nil? || (val.kind_of?(Symbol) && val == :action) || val.kind_of?(String)) ? val : nil
        end

        def type= val
            @type = [:channel, :privmsg, :raw].include?(val) ? val : :channel
        end

        def action= val
            @action = val
        end
    end
end