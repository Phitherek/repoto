require 'yaml'
require 'time'
require 'singleton'
require_relative 'speaker'
require_relative 'ircmessage'
require_relative 'localization'
require_relative 'seen'
require_relative 'alias'

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
            @thr = Thread.new do
                while true
                    @reminders.each_key do |u|
                        if Seen.instance.find(Alias.instance.lookup(u)) == :now
                            current_for_user(Alias.instance.lookup(u)).each do |r|
                                Speaker.instance.enqueue IRCMessage.new("#{Localization.instance.q("functions.remind.reminder_for")} #{r[:time]}: #{r[:msg]}", u, :privmsg)
                                sleep 2
                            end
                            clean_for_user(Alias.instance.lookup(u))
                        end
                    end
                    sleep 10
                end
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

        def stop
            @thr.kill
        end
    end
end
