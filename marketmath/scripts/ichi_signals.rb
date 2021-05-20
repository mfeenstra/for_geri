#!/usr/bin/env ruby

require "#{ENV['HOME']}/marketmath/config/environment"
start_time = Time.now
signals = IchimokuSignalService.new
signals.update
puts "\nfinished in #{((Time.now - start_time)/60).round(3)} minutes.\n\n"
