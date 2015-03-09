require 'singleton'
require_relative 'config'

module Repoto
    class DebugLog
        include Singleton
        def initialize
            if Repoto::Config.instance.debug_log_enabled
                @dlog = File.open(Repoto::Config.instance.debug_log_path, "a")
                puts "Opened debug log..."
            end
        end

        def log_bot(line)
            if Repoto::Config.instance.debug_log_enabled
                @dlog.puts "[" + Time.now.to_s + "] BOT: " + line
                @dlog.flush
            end
        end

        def log_server(line)
            if Repoto::Config.instance.debug_log_enabled
                @dlog.puts "[" + Time.now.to_s + "] SERVER: " + line
                @dlog.flush
            end
        end

        def close
            if Repoto::Config.instance.debug_log_enabled
                @dlog.close
                Singleton.__init__(self)
            end
        end
    end
end
