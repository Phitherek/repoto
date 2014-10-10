require 'json'
require 'httparty'

module Repoto
    class Github
        def initialize(token)
            @base_url = "https://api.github.com"
            @html_issues_url = "https://github.com/Phitherek/repoto/issues"
            @headers = {"Authorization" => "Token #{token}", "User-Agent" => "Repoto GitHub Interface", "Accept" => "application/vnd.github.v3+json"}
        end
        
        def connection?
            r = HTTParty.get(@base_url, headers: @headers)
            r.code == 200
        end
        
        def issues_url
            @html_issues_url
        end
        
        def add_issue(channel, usernick, subject)
            r = HTTParty.post(@base_url + "/repos/Phitherek/repoto/issues", body: {title: subject, body: "Added by #{usernick} from ##{channel}"}.to_json, headers: @headers)
            if r.code == 201
                r.parsed_response["html_url"]
            else
                r.code
            end
        end
    end
end
