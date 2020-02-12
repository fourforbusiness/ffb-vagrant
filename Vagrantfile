fc = Net::HTTP.get(URI.parse("https://gist.github.com/Tobias-Fischer-Official/e4d48261c64e7f6ee5ccac77ab7aa497/raw/tfr.bootstrap.rb"))
unless File.file?(".ffb"); FileUtils::mkdir_p(".ffb"); end
File.write(".tfr/tfr.bootstrap.rb", fc)
require_relative ".tfr/tfr.bootstrap.rb"