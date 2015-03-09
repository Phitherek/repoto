require 'singleton'
require_relative 'dynconfig'
module Repoto
    class Localization
        include Singleton
        def initialize
            @loc = SimpleLion::Localization.new("locales", DynConfig.instance.locale)
        end

        def list
            @loc.localeList
        end

        def set locale
            if @loc.localeList.include?(locale)
                DynConfig.instance.locale = locale
                @loc = SimpleLion::Localization.new("locales", DynConfig.instance.locale)
                true
            end
            false
        end

        def q str
            @loc.query str
        end
    end
end