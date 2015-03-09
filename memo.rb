require 'yaml'
require 'singleton'

module Repoto
    class Memo
        include Singleton
        def initialize
            reload
        end

        def reload
            if File.exists?("memodata.yml")
                @memodata = YAML.load_file("memodata.yml")
            else
                @memodata = {}
            end
            if !@memodata
                @memodata = {}
            end
        end

        def create to, from, memo
            @memodata[to.to_s] ||= []
            @memodata[to.to_s] << {:time => Time.now.to_s, :from => from.to_s, :message => memo.to_s}
        end

        def for_user user
            @memodata[user]
        end

        def delete_user_memos user
            @memodata[user] = []
        end

        def dump
            File.open("memodata.yml", "w") do |f|
                f << YAML.dump(@memodata)
            end
        end
    end
end
