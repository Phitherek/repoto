require 'singleton'
require_relative 'config'
require_relative 'debuglog'

module Repoto
    class Connection
        include Singleton
        def initialize
            connect
        end

        def connect
            @conn = TCPSocket.new Repoto::Config.instance.server, Repoto::Config.instance.port
            puts "NICK #{Repoto::Config.instance.nick}#{!Repoto::Config.instance.suffix.nil? ? "|#{Repoto::Config.instance.suffix}" : ""}"
            Repoto::DebugLog.instance.log_bot "NICK #{Repoto::Config.instance.nick}#{!Repoto::Config.instance.suffix.nil? ? "|#{Repoto::Config.instance.suffix}" : ""}"
            @conn.puts "NICK #{Repoto::Config.instance.nick}#{!Repoto::Config.instance.suffix.nil? ? "|#{Repoto::Config.instance.suffix}" : ""}"
            puts "USER #{!Repoto::Config.instance.suffix.nil? ? "#{Repoto::Config.instance.suffix.downcase}" : ""}-#{Repoto::Config.instance.nick.downcase} 8 * :#{Repoto::Config.instance.nick}"
            Repoto::DebugLog.instance.log_bot "USER #{!Repoto::Config.instance.suffix.nil? ? "#{Repoto::Config.instance.suffix.downcase}" : ""}-#{Repoto::Config.instance.nick.downcase} 8 * :#{Repoto::Config.instance.nick}"
            @conn.puts "USER #{!Repoto::Config.instance.suffix.nil? ? "#{Repoto::Config.instance.suffix.downcase}" : ""}-#{Repoto::Config.instance.nick.downcase} 8 * :#{Repoto::Config.instance.nick}"
        end

        def reconnect
            close
            sleep 60
            connect
        end

        def close
            @conn.close
        end

        def send line
            Repoto::DebugLog.instance.log_bot line
            @conn.puts line
        end

        def recv
            r = @conn.gets
            Repoto::DebugLog.instance.log_server r
            r
        end
    end
end
