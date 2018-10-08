# -*- mode: ruby -*-
# vi: set ft=ruby :

# this file downloads the bootstrapper for the vagrant framework from github

begin
  # try to download the bootstrapper from github
  fc = Net.HTTP.get(URI.parse("https://raw.githubusercontent.com/fourforbusiness/ffb-vagrant/prod/lib/ffb.bootstrap.rb"))
  # create the .ffb-directory if it does not exist yet
  unless File.file?(".ffb"); FileUtils::mkdir_p(".ffb"); end
  # write the file contents
  File.write(".ffb/ffb.bootstrap.rb", fc)
rescue
  # if the file could not be downloaded
  unless File.file?(".ffb/ffb.bootstrap.rb")
    # and does not exist locally, we stop the execution of the program
    raise "Could not download the bootstrapper from GitHub. Please check your internet connection. Exiting..."
  end
  # else we just output an information
  puts "Could not download the bootstrapper from GitHub. Loading the existing File."
end
# load and execute the file we just donwloaded
require_relative ".ffb/ffb.bootstrap.rb"
