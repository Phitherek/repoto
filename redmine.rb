require 'json'
require 'httparty'

module Repoto
    class Redmine
        def initialize(url, apikey)
            @url = url
            @apikey = apikey
        end
        
        def issue_url nr
            @url + "/issues/" + nr.to_s
        end
        
        def issue_data nr
            r = HTTParty.get(@url + "/issues/" + nr.to_s + ".json", headers: {"X-Redmine-API-Key" => @apikey})
            if r.code.to_s == "200"
                JSON.parse(r.body)
            else
                r.code.to_s + " " + r.response
            end
        end
    end
end
