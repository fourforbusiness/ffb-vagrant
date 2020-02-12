require 'open-uri'
fc = open('https://gist.github.com/Tobias-Fischer-Official/e4d48261c64e7f6ee5ccac77ab7aa497/raw/tfr.bootstrap.rb').read

unless File.file?(".tfr"); FileUtils::mkdir_p(".tfr"); end

File.write(".tfr/tfr.bootstrap.rb", fc)

require_relative ".tfr/tfr.bootstrap.rb"