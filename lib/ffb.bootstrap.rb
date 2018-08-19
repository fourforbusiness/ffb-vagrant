# -*- mode: ruby -*-
# vi: set ft=ruby :
#
#
# This file is the entrypoint that loads more ruby-code to execute the vagrant configuration

# include required ruby libs
require 'net/http'
require 'optparse'
# if the tools are already downloaded/existing locally, we load them for logging output
current_working_dir = File.dirname(File.expand_path(__FILE__))
ffb_tools_filename  = "ffb.tools.rb"
ffb_tools_path      = "#{current_working_dir}/#{ffb_tools_filename}"
ffb_tools_exist     = File.file?(ffb_tools_path)
if ffb_tools_exist
  require_relative ffb_tools_path
end
# enum list of possible/known environments for vagrant
module VAGRANT_ENVIRONMENT
  # production is the default env, it loads files from the prod-branch on github
  PRODUCTION  = "prod"
  # development is for changes that are not yet tested for the prod environment
  DEVELOPMENT = "dev"
  # the local environment prevents redownloading the library to make it possible to work on it
  LOCAL       = "local"
  # this environment is excusively used for build-servers, one purpose of it is to prevent console interaction
  BUILD       = "build"
end

# setup paths of directories and files
vagrant_ffb_dirname = ".ffb"
vagrant_ffb_path    = "#{current_working_dir}/#{vagrant_ffb_dirname}"
vagrant_ffb_path    = "#{current_working_dir}"
vagrant_main_script_filename = "ffb.vagrant.rb"
# prod is our default environment
vagrant_environment = "prod"
# $* is an array containing all console arguments
$*.each do |arg|
  # --env is our custom argument
  if arg.match(/^--env/)
    # so we check its value
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
        # keep the default env (prod) set
    end
  end
end

# base url for loading the filesof the framework from git
remote_git_base_uri = "https://raw.githubusercontent.com/fourforbusiness/ffb-vagrant/dev"
# this mapping maps local files and files on git, so the filename on both sides doesn't matter
filename_mapping = [
    { remote: vagrant_main_script_filename, local: vagrant_main_script_filename },
    { remote: "ansible.cfg", local: "ansible.cfg" },
    { remote: "hint.txt", local: "hint.txt" },
    { remote: "vagrant-default-config.yml", local: "vagrant-default-config.yml" },
    { remote: "ffb.tools.rb", local: "ffb.tools.rb" }
]

# if we have loaded the tools containing our logger
if ffb_tools_exist
  # we log the environment we will use
  Tools::Logger.log(Tools::Logger::LOG_LEVEL::INFO,"Detected Vagrant Environment: #{Tools::Logger::LOG_COLOR::ERROR}#{vagrant_environment}#{Tools::Logger::LOG_COLOR::RESET}")
end

# sometimes we want to modify local files and keep the changes for testing purposes
# thats what the local environment is built in for, unless the environment is local, all files will be redownloaded
unless vagrant_environment == VAGRANT_ENVIRONMENT::LOCAL
#download the correct files from gist
  filename_mapping.each do |filename|
    # build local and remote uri
    remote_uri = "#{remote_git_base_uri}/#{vagrant_environment}/lib/#{filename[:remote]}"
    local_uri = "#{vagrant_ffb_path}/#{filename[:local]}"
    begin
      file_contents_downloaded = Net::HTTP.get(URI.parse(remote_uri))
      # if remote files cant be found, use production environment files
      # this helps for diving environmental settings in file or configuration related environments
      # for example the build environment uses the same files like the production environment
      # but the build environment will not ask for host-manager settings, the difference is configuration based
      if(file_contents_downloaded.match(/^Not Found/))
        remote_uri = "#{remote_git_base_uri}/#{VAGRANT_ENVIRONMENT::PRODUCTION}/lib/#{filename[:remote]}"
        file_contents_downloaded = Net::HTTP.get(URI.parse(remote_uri))
      end
      File.write(local_uri, file_contents_downloaded)
    rescue
      if !File.file?(local_uri)
        # without the file we cannot continue
        raise "Could not find #{local_uri} and could not download default Vagrantfile from #{remote_uri}, please check your internet connection to proceed."
      else
        # the file is there, so we just output an information
        if ffb_tools_exist
           Tools::Logger.log(Tools::Logger::LOG_LEVEL::INFO,"Could not download from #{remote_uri}, please check your internet connection.")
        end
      end
    end
  end
end

# execute the ffb vagrant library
load "#{vagrant_ffb_path}/#{vagrant_main_script_filename}"
FfbVagrant::run(vagrant_environment)
