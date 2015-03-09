require 'yaml'
require 'time'
require 'singleton'

module Repoto
    class Reminder
        include Singleton
        def initialize
            reload
        end

        def reload
            if File.exists?("reminders.yml")
               @reminders = YAML.load_file("reminders.yml")
            else
                @reminders = {}
            end
            if !@reminders
                @reminders = {}
            end
        end

        def create user, time, msg
            @reminders[user.to_s] ||= []
            @reminders[user.to_s] << {:time => time, :msg => msg}
        end

        def current_for_user user
            current_reminders = []
            now = Time.now
            if !@reminders[user.to_s].nil?
                @reminders[user.to_s].each do |r|
                    if ((now-r[:time])/60).floor.round >= 0
                        current_reminders << r
                    end
                end
            end
            current_reminders
        end

        def clean_for_user user
            now = Time.now
            if !@reminders[user.to_s].nil?
                @reminders[user.to_s].each do |r|
                    if ((now-r[:time])/60).ceil.round > 0
                        @reminders[user.to_s].delete(r)
                    end
                end
            end
        end

        def dump
            File.open("reminders.yml", "w") do |f|
                f << YAML.dump(@reminders)
            end
        end
    end
end
