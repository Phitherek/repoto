require 'singleton'
require_relative 'config'

module Repoto
    class Connection
        include Singleton
        def initialize
            connect
        end
        
        def connect
            
        end
        
        def reconnect
            
        end
        
        def close
            
        end
        
        def send line
            
        end
        
        def recv
            
        end
    end
end
