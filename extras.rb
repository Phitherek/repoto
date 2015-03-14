require_relative 'config'
require_relative 'memo'
require_relative 'redmine'
require_relative 'alias'
require_relative 'speaker'
require_relative 'ircmessage'
require_relative 'localization'
module Repoto
    class Extras
        if Config.instance.redmine_enabled
            @@redmine = Redmine.new(Config.instance.redmine_url, Config.instance.redmine_api_key)
        end
        def self.parse line
            if !line.nil? && line.kind_of?(IRCLine)
                Thread.new do
                    if Unicode.upcase(line.formatted_message).match(/.*MAKA.*PAKA.*/) != nil
                        if !Memo.instance.for_user(Alias.instance.lookup(line.usernick)).nil? || !Memo.instance.for_user(Alias.instance.lookup(line.usernick)).empty?
                            Memo.instance.for_user(Alias.instance.lookup(line.usernick)).each do |m|
                                Speaker.instance.enqueue IRCMessage.new("#{Localization.instance.q("functions.memo.memo_from")} #{m[:from]} #{Localization.instance.q("functions.memo.received")} #{m[:time]}: #{m[:message]}", line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                                sleep(1)
                            end
                        end
                        Memo.instance.delete_user_memos(Alias.instance.lookup(line.usernick))
                    end
                    if Config.instance.redmine_enabled && line.formatted_message[/redmine:#[0-9]+/] != nil
                        begin
                            line.formatted_message.scan(/redmine:#[0-9]+/).each do |s|
                                nr = s.gsub("redmine:#", "").to_i
                                idata = @@redmine.issue_data nr
                                if idata.kind_of?(Hash)
                                    Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("redmine.title") + " " + Localization.instance.q("redmine.issue_url") + " " + @@redmine.issue_url(nr), (line.target == Config.instance.formatted_channel) ? nil : line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                                    sleep(1)
                                    Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("redmine.issue_data"), (line.target == Config.instance.formatted_channel) ? nil : line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                                    sleep(1)
                                    Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("redmine.issue_subject") + " " + idata["issue"]["subject"], (line.target == Config.instance.formatted_channel) ? nil : line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                                    sleep(1)
                                    Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("redmine.issue_tracker") + " " + idata["issue"]["tracker"]["name"], (line.target == Config.instance.formatted_channel) ? nil : line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                                    sleep(1)
                                    Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("redmine.issue_project") + " " + idata["issue"]["project"]["name"], (line.target == Config.instance.formatted_channel) ? nil : line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                                    sleep(1)
                                    Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("redmine.issue_author") + " " + idata["issue"]["author"]["name"], (line.target == Config.instance.formatted_channel) ? nil : line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                                    sleep(1)
                                    Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("redmine.issue_assignee") + " " + (idata["issue"]["assigned_to"].nil? ? Localization.instance.q("redmine.none") : idata["issue"]["assigned_to"]["name"]), (line.target == Config.instance.formatted_channel) ? nil : line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                                    sleep(1)
                                    Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("redmine.issue_status") + " " + idata["issue"]["status"]["name"], (line.target == Config.instance.formatted_channel) ? nil : line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                                    sleep(1)
                                    Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("redmine.issue_done") + " " + idata["issue"]["done_ratio"].to_s, (line.target == Config.instance.formatted_channel) ? nil : line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                                    sleep(1)
                                else
                                    Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("redmine.query_error") + " " + idata, (line.target == Config.instance.formatted_channel) ? nil : line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                                end
                            end
                        rescue => e
                            Speaker.instance.enqueue IRCMessage.new(Localization.instance.q("redmine.query_error") + " " + e.to_s, (line.target == Config.instance.formatted_channel) ? nil : line.usernick, (line.target == Config.instance.formatted_channel) ? :channel : :privmsg)
                        end
                    end
                end
            end
        end
    end
end