require 'httparty'
require 'json'

module Repoto
    class Graphite
        def initialize(baseurl)
            @baseurl = baseurl + "/render/?&format=json"
        end

        def hs_list
            r = HTTParty.get(@baseurl + "&target=hs.hardroom.*&maxDataPoints=1")
            if r.code.to_s == "200"
                p = JSON.parse(r.body)
                res = []
                p.each do |elem|
                    res << elem["target"].split(".").last
                end
                res
            else
                r.code + " " + r.response
            end
        end

        def hs_current sensor
            r = HTTParty.get(@baseurl + "&target=hs.hardroom.#{sensor}&maxDataPoints=1&from=-10min")
             if r.code.to_s == "200"
                p = JSON.parse(r.body)
                if p.empty?
                    "empty"
                else
                    [p.first["target"], p.first["datapoints"].first[0], Time.at(p.first["datapoints"].first[1].to_i)]
                end
            else
                r.code + " " + r.response
            end
        end

        def hs_avg sensor, datapoints
            if datapoints.nil? || datapoints.to_i < 1
                "wrongdatapointsvalue"
            else
                datapoints = datapoints.to_i
                r = HTTParty.get(@baseurl + "&target=hs.hardroom.#{sensor}&maxDataPoints=#{datapoints.to_s}&from=-10min")
                 if r.code.to_s == "200"
                    p = JSON.parse(r.body)
                    if p.empty?
                        "empty"
                    else
                        avgval = 0.0
                        p.first["datapoints"].each do |point|
                            if !point[0].nil?
                                avgval += point[0]
                            else
                                datapoints -= 1
                            end
                        end
                        if datapoints < 1
                            "wrongdatapointsvalue"
                        else
                            avgval = avgval/datapoints
                            [p.first["target"], avgval, datapoints]
                        end
                    end
                else
                    r.code + " " + r.response
                end
            end
        end
    end
end
