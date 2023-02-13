require 'active_support/core_ext/integer/inflections'

Time::DATE_FORMATS.merge!(
  default: ->(time) { time.to_s(:date) + ', ' + time.to_s(:time) },
  date: ->(time) { time.to_date.to_s },
  time: ->(time) { time.strftime("#{(t = time.hour % 12) == 0 ? 12 : t}:%M#{time.strftime('%p').downcase}") }
)

Date::DATE_FORMATS.merge!(
  default: ->(date) { date.strftime("%a #{date.day.ordinalize} %b %Y") },
  post: ->(date) { date.strftime("#{date.day} %b#{" #{date.year}" unless date.year == Date.today.year}") }
)


module ActiveSupport
  class TimeWithZone
    def to_s(format = :default)
      if formatter = Time::DATE_FORMATS[format]
        if formatter.respond_to?(:call)
          formatter.call(self).to_s
        else
          strftime(formatter)
        end
      else
        to_default_s
      end
    end
  end
end

class Time
  def to_s(format = :default)
    if formatter = Time::DATE_FORMATS[format]
      if formatter.respond_to?(:call)
        formatter.call(self).to_s
      else
        strftime(formatter)
      end
    else
      to_default_s
    end
  end
end

class Date
  def to_s(format = :default)
    if formatter = Date::DATE_FORMATS[format]
      if formatter.respond_to?(:call)
        formatter.call(self).to_s
      else
        strftime(formatter)
      end
    else
      to_default_s
    end
  end
end


