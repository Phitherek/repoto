require 'singleton'

module Repoto
    class ServicesAuth
        include Singleton
        
        def initialize
            @imsg_enabled = false
            @nickserv_present = true
        end
        
        def method
            if @imsg_enabled
                :imsg
            elsif @nickserv_present
                :acc
            else
                :none
            end
        end
        
        def enable_imsg!
            @imsg_enabled = true
        end
        
        def disable_nickserv!
            @nickserv_present = false
        end
    end
end
