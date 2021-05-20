class IchimokuCrossingsService
  attr_reader :symbol, :golden, :death
  def initialize(symbol)
    @symbol = symbol.to_s.downcase
    @death = []
    @golden = []
    skip_next = false
    start = Time.now
    average_data = Ticker.find_by(symbol: @symbol).ichimoku_price.order(:date)
    prices = Ticker.find_by(symbol: @symbol).price.order(:date)

    print "INFO: IchimokuCrossingService: calculating #{@symbol.upcase} for #{average_data.size} days"
    average_data.each_with_index do |ichi, i|
      if i % 100 == 0 then print '.' end
      if skip_next then
        skip_next = false
        next
      end
      unless ichi.tenkan.blank? || ichi.kijun.blank? ||
             average_data[i - 1].tenkan.blank? || average_data[i + 1].blank? ||
             average_data[i - 1].kijun.blank? || average_data[i + 1].kijun.blank? then
        price = prices.find_by(date: ichi.date).close.to_f
        price_index = prices.pluck(:date).index(ichi.date)
        days_ago = prices.size - i
        delta_prev = (average_data[i - 1].tenkan - average_data[i - 1].kijun).round(sigfigs(price))
        delta_middle = (average_data[i].tenkan - average_data[i].kijun).round(sigfigs(price))
        delta_next = (average_data[i + 1].tenkan - average_data[i + 1].kijun).round(sigfigs(price))
        if (delta_prev > 0.0) && (delta_next < 0.0) then
          @death << {
                      index_day: price_index, date: ichi.date, business_days_ago: days_ago,
                      price: price, longavg: ichi.tenkan, shortavg: ichi.kijun
                    }
          skip_next = true
          next
        end
        if (delta_prev < 0.0) && (delta_next > 0.0) then
          @golden << {
                       index_day: price_index, date: ichi.date, business_days_ago: days_ago,
                       price: price, longavg: ichi.tenkan, shortavg: ichi.kijun
                     }
          skip_next = true
          next
        end
      end
    end
    print "saving.."
    save_crossings
    puts "\nINFO: #{@symbol.upcase} crossings completed on '#{Socket.gethostname}' in " \
         "#{((Time.now - start)/60.0).round(2)} minutes with #{@golden.size} golden and " \
         "#{@death.size} death (ichimoku) crossings."
    rescue => e
      puts %(ERROR: IchimokuCrossingService#initialize: #{e}\n---\n#{e.backtrace.join("\n")})
    end
  end

  private

  def save_crossings
    ticker = Ticker.find_by(symbol: @symbol)
    crossings_data = {
                       symbol: @symbol,
                       golden_crosses: @golden,
                       death_crosses: @death,
                       long_radius: nil,
                       short_radius: nil,
                       date_calculated: Date.today
                     }

    if ticker.crossing.blank? then
      puts "creating new crossings data for #{@symbol}"
      ticker.crossing = Crossing.create crossings_data
    else
      puts "updating crossings data for #{@symbol}"
      ticker.crossing.update crossings_data
    end
    # save also done as the last step in StatsService..
    ticker.save
  end

  def sigfigs(price)
    dmag = price.round.to_s.size
    case
    when dmag <= 1
      return 4
    when dmag == 2
      return 3
    when dmag == 3
      return 2
    when dmag == 4
      return 1
    when dmag >= 5
      return 0
    else
      return 2
  end

end # class
