# -*- mode: ruby -*-
# vi: set ft=ruby :
#

# This file is just the entrypoint that loads more ruby-code to execute the vagrant configuration
current_working_dir = File.dirname(File.expand_path(__FILE__))
vagrant_ffb_dirname = ".ffb"
vagrant_ffb_path = "#{current_working_dir}/#{vagrant_ffb_dirname}"

require 'net/http'
require 'optparse'
ffb_tools_filename = "ffb.tools.rb"
ffb_tools_path = "#{current_working_dir}/#{ffb_tools_filename}"
if File.file?(ffb_tools_path)
  require ffb_tools_path
end

vagrant_ffb_path = "#{current_working_dir}"
vagrant_environment_separator = "_"
vagrant_main_script_filename = "ffb.vagrant.rb"
vagrant_environment = "prod"

module VAGRANT_ENVIRONMENT
  PRODUCTION  = "prod"
  DEVELOPMENT = "dev"
  LOCAL       = "local"
  BUILD       = "build"
end

$*.each do |arg|
  if arg.match(/^--env/)
    arg_param = arg.split('=')[1]
    case arg_param
      when VAGRANT_ENVIRONMENT::PRODUCTION
        vagrant_environment = VAGRANT_ENVIRONMENT::PRODUCTION
      when VAGRANT_ENVIRONMENT::LOCAL
        vagrant_environment = VAGRANT_ENVIRONMENT::LOCAL
      when VAGRANT_ENVIRONMENT::DEVELOPMENT
        vagrant_environment = VAGRANT_ENVIRONMENT::DEVELOPMENT
      when VAGRANT_ENVIRONMENT::BUILD
        vagrant_environment = VAGRANT_ENVIRONMENT::BUILD
      else
        # do nothing
    end
  end
end

remote_gist_base_uri = "https://gist.githubusercontent.com/tfr-ffb/7e1ac6dcdc7d168e63ecb87601a75821/raw/"
filename_mapping = [
    { remote: vagrant_main_script_filename, local: vagrant_main_script_filename },
    { remote: "ansible.cfg", local: "ansible.cfg" },
    { remote: "hint.txt", local: "hint.txt" },
    { remote: "vagrant-default-config.yml", local: "vagrant-default-config.yml" },
    { remote: "ffb.tools.rb", local: "ffb.tools.rb" }
]

if File.file?(ffb_tools_path)
  Tools::Logger.log(Tools::Logger::LOG_LEVEL::INFO,"Detected Vagrant Environment: #{Tools::Logger::LOG_COLOR::ERROR}#{vagrant_environment}#{Tools::Logger::LOG_COLOR::RESET}")
end

# sometimes we want to modify local files and keep the changes for testing purposes
# thats what the local environment is built in for, unless the environment is local, all files will be redownloaded
unless vagrant_environment == VAGRANT_ENVIRONMENT::LOCAL
#download the correct files from gist
  filename_mapping.each do |filename|
    # build local and remote uri
    remote_uri = "#{remote_gist_base_uri}#{filename[:remote]}#{vagrant_environment_separator}#{vagrant_environment}"
    local_uri = "#{vagrant_ffb_path}/#{filename[:local]}"
    begin
      file_contents_downloaded = Net::HTTP.get(URI.parse(remote_uri))
      # if remote files cant be found, use production environment files
      # this helps for diving environmental settings in file or configuration related environments
      # for example the build environment uses the same files like the production environment
      # but the build environment will not ask for host-manager settings
      if(file_contents_downloaded.match(/^404: Not Found/))
        remote_uri = "#{remote_gist_base_uri}#{filename[:remote]}#{vagrant_environment_separator}#{VAGRANT_ENVIRONMENT::PRODUCTION}"
        file_contents_downloaded = Net::HTTP.get(URI.parse(remote_uri))
      end
      File.write(local_uri, file_contents_downloaded)
    rescue
      if !File.file?(local_uri)
        # without the file we cannot continue
        raise "Could not find #{local_uri} and could not download default Vagrantfile from #{remote_uri}, please check your internet connection to proceed."
      else
        # the file is there, so we just output an information
        if File.file?(ffb_tools_path)
           Tools::Logger.log(Tools::Logger::LOG_LEVEL::INFO,"Could not download from #{remote_uri}, please check your internet connection.")
        end
      end
    end
  end
end

# execute the ffb vagrant library
load "#{vagrant_ffb_path}/#{vagrant_main_script_filename}"
FfbVagrant::run(vagrant_environment)