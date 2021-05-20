
class IchimokuSignalService
  attr_reader :data, :within_days, :logfile

  def initialize(args = { symbols: 'none_given', days: MM.ichimoku_signal_within_days })
    start_time = Time.now
    log 'INFO: IchimokuSignalService Begin'
    @within_days = args[:days]
    symbols = args[:symbols]
    @logfile = "#{Rails.root}/log/ichimoku_signals.log"
    @output_file = "#{Rails.root}/config/ichimoku_signals_#{@within_days}_days.yml"
    # it is best to be inside or above the green rising kumo cloud
    @data = {
              golden_cross: [],
              symbols: [],
              above_kumo_cloud: [],
              inside_kumo_cloud: [],
              underneath_kumo_cloud: [],
              yellow_kumo_cloud: []
            }
    if symbols == 'none_given' then
      Ticker.all.each_with_index do |t, i|
        if t.blank? then log("WARNING: IchimokuSignalService: Ticker is blank entry"); next end
        if t.crossing.blank? then log("#{t.symbol}.crossing is blank."); next end
        run_comparison(t.symbol.to_s)
      end
    else
      if symbols.is_a? String then run_comparison(symbols) end
    end
    log "INFO: IchimokuSignalService#initialize finished in #{((Time.now - start_time) / 60).round(3)} minutes."
    @data
  end

  def update
    if @data.empty? then
      log = 'ERROR: IchimokuSignalService.update ran with no @data!'
      return
    end
    begin
      puts "INFO: IchimokuSignalService writing #{@output_file}.."
      outfile = File.open(@output_file, 'w')
      outfile.puts @data.to_yaml(Indent: 4, UseHeader: true, UseVersion: true)
      outfile.close
    rescue => e
      log "ERROR: IchimokuSignalService: Could not write #{@output_file}! : " \
          "#{e}\n---\n##{e.backtrace}"
    end
    return 0
  end

  def show
    unless @data.blank? then puts @data.inspect else log "ERROR: IchimokuSignalService#print: Blank data!" end
  end

  private

  def run_comparison(symbol)
    begin
      t = Ticker.find_by(symbol: symbol)
      if !t.blank? && !t.crossing.blank? && (g = t.crossing.golden_crosses) then
        unless g.last.blank? || g.last[:business_days_ago].blank? then
          if g.last[:business_days_ago].to_i <= @within_days then
            span_a = t.ichimoku_price.where(date: g.last[:date]).as_json.first['span_a']
            span_b = t.ichimoku_price.where(date: g.last[:date]).as_json.first['span_b']
            unless g.last[:date].blank? || span_a.blank? || span_b.blank? then
              print "Found! #{t.symbol} "
              if g.last[:price] >= span_a then
                print "(A) "
                @data[:above_kumo_cloud] << t.symbol
              end
              if g.last[:price] < span_a && g.last[:price] > span_b then
                print "(i) "
                @data[:inside_kumo_cloud] << t.symbol
              end
              if g.last[:price] <= span_b then
                print "(u) "
                @data[:underneath_kumo_cloud] << t.symbol
              end
              if span_b > span_a then
                print  "(y) "
                @data[:yellow_kumo_cloud] << t.symbol
              end
              puts
              @data[:symbols] << t.symbol.upcase
              @data[:golden_cross] << [ t.symbol, g.last[:business_days_ago], g.last[:price] ]
            end
          end
        else
          log "None Found: #{symbol.upcase}"
        end
      else
        log "WARNING: Ticker #{symbol} is blank!!"
      end
    rescue => e
      log "ERROR: run_comparison failed on #{symbol}: #{e}\n---\n#{e.backtrace.join("\n")}\n\n"
    end
  end

  def log(message)
    puts message
    logger = Logger.new(@logfile, 10, 1024000, datetime_format: '%Y-%m-%d %H:%M:%S')
    logger.level = Logger::INFO
    logger.info "\n#{eval DBUG}\n#{message}"
    logger.close
    message
  end

end
