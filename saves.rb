require 'yaml'

module Repoto
    class Saves
        def initialize
            @savedata = []
        end

        def log msg
            if @savedata.count == 30
                @savedata.delete_at(0)
            end
            @savedata << msg
        end

        def save user
            saves = []
            if File.exists?("saves.yml")
                saves = YAML.load_file("saves.yml")
            end
            if !saves
                saves = []
            end
            saves << {:user => user.to_s, :time => Time.now.to_s, :content => @savedata.join("\n")}
            File.open("saves.yml", "w") do |f|
                f << YAML.dump(saves)
            end
        end
    end
end
