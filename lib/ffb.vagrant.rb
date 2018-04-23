# -*- mode: ruby -*-
# vi: set ft=ruby :

# load required ruby libraries
require 'yaml'
require 'fileutils'
require 'net/http'
require 'io/console'
# load our custom tools from folder ./
require File.dirname(File.expand_path(__FILE__)) + "/ffb.tools.rb"

class FfbVagrant
  # extend the current class with the methods from the tools-module
  extend Tools
  # string constants
  DEFAULT_CONFIG_FILENAME  = "vagrant-default-config.yml"
  PROJECT_CONFIG_FILENAME  = "vagrant-project-config.yml"
  LOCAL_CONFIG_FILENAME    = "vagrant-local-config.yml"
  OVERRIDE_CONFIG_FILENAME = "vagrant-override-config.yml"
  LOCAL_USER_SETTINGS_DIR  = "~/.fourforbusiness_vagrant"


  def FfbVagrant.run(vagrant_environment)

    logger             = Tools::Logger
    log_level          = logger::LOG_LEVEL

    vagrant_command = 'unknown'
    ARGV.each do |cmd_arg|
      vagrant_args = ['box', 'connect', 'destroy', 'global-status', 'halt', 'init', 'login', 'package', 'plugin', 'port', 'powershell', 'provision', 'rdp', 'reload', 'resume', 'share', 'snapshot', 'ssh', 'ssh-config', 'status', 'suspend', 'up', 'validate', 'version']
      if vagrant_args.include?(cmd_arg)
        vagrant_command = cmd_arg
        break
      end
    end

    logger.log(log_level::INFO, "Detected Vagrant Command: #{logger::LOG_COLOR::ERROR}#{vagrant_command}#{logger::LOG_COLOR::RESET}")
    # shortcuts
    # directories
    self_dir           = File.dirname(File.expand_path(__FILE__))
    vagrant_root       = File.expand_path("#{self_dir}/..")
    project_root       = File.expand_path("#{vagrant_root}/..")
    vagrant_temp_dir   = ".vagrant"
    ffb_temp_dir       = ".ffb"
    user_settings_dir  = File.expand_path(LOCAL_USER_SETTINGS_DIR)
    # config file paths
    default_conf_path  = "#{self_dir}/#{DEFAULT_CONFIG_FILENAME}"
    project_conf_path  = "#{vagrant_root}/#{PROJECT_CONFIG_FILENAME}"
    local_conf_path    = "#{user_settings_dir}/#{LOCAL_CONFIG_FILENAME}"

    # run our little setup routine
    Tools::User.setup(LOCAL_USER_SETTINGS_DIR, LOCAL_CONFIG_FILENAME, vagrant_environment)

    # load all configurations
    default_conf       = Tools::Data.getyaml(default_conf_path,  true, false, "default configuration")
    project_conf       = Tools::Data.getyaml(project_conf_path,  true, false, "project configuration")
    conf               = Tools::Data.rec_deep_merge(project_conf, default_conf)
    conf[:guests].each do |key, value|
      default_guest = conf[:default_guest].dup
      conf[:guests][key] = Tools::Data.rec_deep_merge(conf[:guests][key], default_guest)
    end
    local_conf         = Tools::Data::getyaml(local_conf_path, false, true, "local configuration")
    conf               = Tools::Data.rec_deep_merge(local_conf.nil? ? {} : local_conf, conf)
    override_conf_path = "#{LOCAL_USER_SETTINGS_DIR}/#{conf[:project][:tag]}/#{OVERRIDE_CONFIG_FILENAME}"
    override_conf      = Tools::Data::getyaml(override_conf_path, false, true, "override configuration")
    conf               = Tools::Data.rec_deep_merge(override_conf.nil? ? {} : override_conf, conf)

    # setup shortcut vars
    tag = conf[:project][:tag]
    # make sure we have the correct vagrant version installed
    Vagrant.require_version conf[:vagrant][:version]
    conf[:guests].each do |guest_id, guest|
      # Make sure all required plugins are installed
      guest[:box][:vagrant][:plugins].each do |plugin_os, plugins|
        if Tools::System::detect.eql?(plugin_os)
          # when nfs is enabled for a folder we have to make sure some plugins are installed on the host system
          guest[:box][:filesystem][:folders].each do |folder_name, folder|
            if folder[:mounttype].eql? Tools::Enum::FILEMOUNT_TYPE::NFS
              logger.log(log_level::INFO, "Detected NFS, requiring additional plugins")
              plugins[:load].push('vagrant-bindfs')
              if  Tools::System::detect.eql? Tools:System::OS_TYPE::WIN
                plugins[:load].push('vagrant-winnfsd')
              end
            end
          end
          errors = []
          if plugins[:load].length > 0
            plugins[:load].each do |plugin|
              unless Vagrant.has_plugin?(plugin[:name])
                errors.push("#{plugin[:name]} is required. Please run `vagrant plugin install #{plugin[:name]}`")
              end
            end
          end
          if errors.length > 0
            errors.push(File.read("hint.txt"))
            logger.log(log_level::ERROR, "Plugins are missing:\n\n" + errors.join("\n") + "\n\n")
            exit 1
          end
        end
      end
    end

    # start VM configuration
    logger.log(log_level::INFO, "All Settings successfully loaded.")

    # -----------------------------------
    # ---------vagrant configure---------
    # -----------------------------------
    Vagrant.configure("2") do |config|
      # -----------------------------------
      # ---------setup hostmanager---------
      # -----------------------------------
      if Vagrant.has_plugin?("vagrant-hostmanager")
          logger.log(log_level::INFO, "Host manager plugin found, loading settings")
          config.hostmanager.enabled      = conf[:vagrant][:hostmanager][:enabled]
          config.hostmanager.manage_host  = conf[:vagrant][:hostmanager][:manage_host]
          config.hostmanager.manage_guest = conf[:vagrant][:hostmanager][:manage_guest]
      else
        logger.log(log_level::INFO, "Host manager plugin not found, if you like to let Vagrant manage the Hosts")
        logger.log(log_level::INFO, "It's recommended to install it via `vagrant plugin install vagrant-hostmanager`")
      end
      # -----------------------------------
      # ---------configure guests----------
      # -----------------------------------
      conf[:guests].each do |guest_id, guest|
        # variable shortcuts
        gid             = "#{guest_id.to_s}_#{tag}_#{guest[:postfix]}"
        guest_host_name = guest[:box][:network].key?(:hostname) ? guest[:box][:network][:hostname] : "#{guest_id.to_s}.#{tag}.#{guest[:postfix]}"
        gip             = guest[:box][:network][:nics][:default][:ip]
        # -----------------------------------
        # ---------configure guest-----------
        # -----------------------------------
        config.vm.define(gid) do |box|
          # setup quick info output after booting the guest
          info = {
            :intro    => "#{logger::LOG_COLOR::INFO}Guest-Infos for the project#{logger::LOG_COLOR::INFO}\n\n",
            :tag      => "#{logger::LOG_COLOR::INFO}Project-Tag:\t\t#{tag}#{logger::LOG_COLOR::INFO}\n",
            :hosts    => "#{logger::LOG_COLOR::INFO}Using Hostmanager:\t#{conf[:vagrant][:hostmanager][:manage_host]}#{logger::LOG_COLOR::INFO}",
            :guest    => "\n  #{logger::LOG_COLOR::WARNING}\t\tGuest [#{gid}]#{logger::LOG_COLOR::INFO}\n",
            :domain   => "  #{logger::LOG_COLOR::ERROR}Hostname:\t\t#{guest_host_name}#{logger::LOG_COLOR::INFO}\n",
            :ip       => "  #{logger::LOG_COLOR::ERROR}IP (default):\t\t#{gip}#{logger::LOG_COLOR::INFO}\n",
            :os       => "  #{logger::LOG_COLOR::ERROR}Guest-Os:\t\t#{guest[:box][:name]}#{logger::LOG_COLOR::INFO}\n",
            :ssh_file => "  #{logger::LOG_COLOR::ERROR}Ssh-File:\t\t#{vagrant_root}/#{vagrant_temp_dir}/machines/#{gid}/[provider]/private_key#{logger::LOG_COLOR::INFO}\n",
            :def_pass => "  #{logger::LOG_COLOR::ERROR}MySQL-Pw(default):\t#{tag}#{logger::LOG_COLOR::INFO}\n",
            :hint     => "#{logger::LOG_COLOR::WARNING}Please read the readme.md before you start working.#{logger::LOG_COLOR::INFO}\n",
            :outro    => "#{logger::LOG_COLOR::INFO}"
          }
          box.vm.post_up_message = info.values.join("\t\t");

          # setup guest box
          box.vm.box      = guest[:box][:name]
          box.vm.box_url  = guest[:box][:url]

          # configure network for guest
          guest[:box][:network][:nics].each do |name, nic|
            logger.log(log_level::INFO, "#{gid} --> Configuring network '#{name}'")
            # network type is optional, default is always private
            nic_type = "private_network"
            if nic.key?(:type)
              nic_type = nic[:type]
            end
            box.vm.network "#{nic_type}", ip: nic[:ip]
          end

          # set hostname
          box.vm.hostname = guest_host_name

          # configure virtual boxes, so the VM will have the appropriate name and ressources
          # -----------------------------------
          # -----configure boxes for guest-----
          # -----------------------------------
          guest[:box][:provider].each do |provider_name, box_settings|
            case provider_name.to_s
              when Tools::Enum::PROVIDER::VIRTUALBOX
                logger.log(log_level::INFO, "#{gid} --> Configuring virtualization provider #{provider_name}")
                # -----------------------------------
                # -----------configure box-----------
                # -----------------------------------
                box.vm.provider(provider_name.to_s) do |box|
                  box.name = gid
                  box.customize ["modifyvm", :id, "--cpus",         box_settings[:cpus]]
                  box.customize ["modifyvm", :id, "--ioapic",       box_settings[:ioapic]]
                  box.customize ["modifyvm", :id, "--memory",       box_settings[:memory]]
                  box.customize ["modifyvm", :id, "--natdnsproxy1", box_settings[:natdnsproxy1]]
                  # ubuntu xenial box fix to prevent logfile creation (this is why we can't have nice things! (╯°□°）╯︵ ┻━┻))
                  box.customize ["modifyvm", :id, "--uartmode1",    "disconnected"]
                end
              else
                # we currently do not support other types of providers, but they can be added here easily if needed
                logger.log(log_level::ERROR, "#{gid} --> Unknown/Unimplemented VM Provider '#{provider_name.to_s}'.\nSkipping...")
            end
          end

          # -----------------------------------
          # -------configure provisioners------
          # -----------------------------------
          guest[:box][:provisioner].each do |provisioner_name, provisioner|
            # directory shortcut variables
            pdir = provisioner[:dir]
            vagrant_local_cwd = "#{vagrant_root}"
            vagrant_remote_cwd = "/vagrant"

            logger.log(log_level::INFO, "#{gid} --> Configuring provisioner [#{provisioner_name}].")
            # check selected provisioner
            case provisioner_name.to_s
              # -----------------------------------
              # ---------ansible configure---------
              # -----------------------------------
              when Tools::Enum::PROVISIONER::ANSIBLE
                # decide whether to use ansible on the host or the guest system
                # this check is mandatory for working under windows
                ansible_mode = Tools::System::detect.eql?(Tools::System::OS_TYPE::WIN) == true ? "ansible_local" : "ansible"
                # its possible to force ansible local provision if needed
                ansible_mode = provisioner[:force_local] == true ? "ansible_local" : ansible_mode
                # if ansible is running on the host machine, we do not need any remote paths,
                # but if its running in the guest, we need to use guest-specific paths
                local_ansible_base_dir       = "#{vagrant_local_cwd}/#{pdir[:cwd]}"
                remote_ansible_base_dir      = "#{vagrant_remote_cwd}/#{pdir[:cwd]}"
                
                if ansible_mode == "ansible"
                  logger.log(log_level::INFO, "#{gid} --> Ansible will run on the Host-Machine - cwd: #{local_ansible_base_dir}")
                  remote_ansible_base_dir = local_ansible_base_dir
                  vagrant_remote_cwd = vagrant_local_cwd
                else
                  logger.log(log_level::INFO, "#{gid} --> Ansible will run on the Guest-Machine (ansible_local) - cwd: #{remote_ansible_base_dir}")
                end

                provisioning_check_file_path = "#{vagrant_local_cwd}/#{vagrant_temp_dir}/machines/#{gid}"
                ansible_cfg_path             = "#{vagrant_remote_cwd}/#{ffb_temp_dir}/#{pdir[:cfg_file]}"
                galaxy_requirements_path_loc = "#{local_ansible_base_dir}/#{pdir[:galaxy][:requirements_dir]}/#{pdir[:galaxy][:requirements_file]}"
                ffb_roles_dir                = "#{local_ansible_base_dir}/#{pdir[:galaxy][:roles]}/fourforbusiness.*"

                galaxy_requirements_path_rem = "#{remote_ansible_base_dir}/#{pdir[:galaxy][:requirements_dir]}/#{pdir[:galaxy][:requirements_file]}"
                roles_search_path            = "#{remote_ansible_base_dir}/#{pdir[:galaxy][:roles]}:#{remote_ansible_base_dir}/#{pdir[:roles]}"
                remote_playbooks_dir         = "#{remote_ansible_base_dir}/#{pdir[:playbooks]}"

                # check if
                provisioning_done = true
                guest[:box][:provider].each do |provider, data|
                  provisioning_done = provisioning_done && File.exists?("#{provisioning_check_file_path}/#{provider}/action_provision")
                end

                # delete fourforbusiness roles if provisioning is planned, so we ensure we always have the latest version
                if vagrant_command.eql?('provision') || !provisioning_done
                  logger.log(log_level::INFO, "#{gid} --> Deleting ffb galaxy-roles from #{ffb_roles_dir}")
                  FileUtils.rm_rf(Dir.glob(ffb_roles_dir))
                end

                provisioner[:playbooks].each do |playbook|
                  # directory shortcut variables
                  playbook_path = "#{remote_playbooks_dir}/#{playbook}"

                  logger.log(log_level::INFO, "#{gid} --> Reading ansible configuration for playbook #{playbook}")
                  # run ansible configuration
                  box.vm.provision(ansible_mode) do |ansible| :hostmanager
                    ansible.playbook = playbook_path
                    # requirements file is mandatory in our workflow
                    if File.file?(galaxy_requirements_path_loc)
                      ansible.galaxy_role_file = galaxy_requirements_path_rem
                    else
                      logger.log(log_level::ERROR, "#{gid} --> The configured vagrant requirements file could not be found in #{galaxy_requirements_path_loc}\n. Exiting...")
                      exit 1
                    end
                    # setup ansible
                    ansible.galaxy_roles_path = roles_search_path
                    ansible.config_file       = ansible_cfg_path
                    ansible.galaxy_command    = provisioner[:galaxy][:cmd]
                    ansible.verbose           = provisioner.has_key?(:log_level) == true ? provisioner[:log_level] : nil
                    ansible_extra_vars        = provisioner.has_key?(:extra_vars) == true ? provisioner[:extra_vars] : { }
                    # add custom extra vars
                    vagrant_extra_vars = {
                      app_host:               guest_host_name,
                      project_tag:            tag,
                      lamp_prepare_doc_root:  guest[:box][:filesystem][:prepare_web_root],
                      synched_folders:        guest[:box][:filesystem][:folders]
                    }
                    ansible.extra_vars = Tools::Data.rec_deep_merge(vagrant_extra_vars, ansible_extra_vars)
                  end
                end
              else
                # we currently do not support other types of provisioners, but they can be added here easily if needed
                logger.log(log_level::ERROR, "#{gid} --> Unknown/Unimplemented Provisioner '#{provisioner_name}'.\nSkipping...")
              end
          end

          guest[:box][:filesystem][:folders].each do |folder_name, folder|
            case folder[:mounttype]
              when Tools::Enum::FILEMOUNT_TYPE::NFS
                logger.log(log_level::INFO, "#{gid} --> Configuring sync for #{folder_name.to_s}.")
                box.vm.synced_folder(
                  # source and destination folder
                  "#{folder[:src]}",
                  "#{folder[:nfs][:bind_folder]}",
                  # nfs settings
                  nfs:                true,
                  mount_options:      ['rw', 'actimeo=1'],
                  nfs_version:        3,
                  nfs_udp:            false,
                  linux__nfs_options: ['rw','no_subtree_check','all_squash']
                )
                if Vagrant.has_plugin?("vagrant-bindfs")
                  logger.log(log_level::INFO, "#{gid} --> Bindfs detected.")
                  box.bindfs.bind_folder(
                    "#{folder[:nfs][:bind_folder]}",
                    "#{folder[:dst_base]}/#{folder[:dst_target]}",
                    :noacl             =>  false,
                    :owner             => "#{folder[:nfs][:owner]}",
                    :group             => "#{folder[:nfs][:group]}",
                    'create-as-user'   => folder[:nfs][:create_as_user],
                    :perms             => "#{folder[:nfs][:perms]}",
                    'create-with-perms'=> "#{folder[:nfs][:create_with_perms]}",
                    ':chown-normal'    => folder[:nfs][:chown_ignore],
                    ':chgrp-normal'    => folder[:nfs][:chgrp_ignore],
                    ':chmod-normal'    => folder[:nfs][:chmod_ignore]
                  )
                end
              when Tools::Enum::FILEMOUNT_TYPE::NONE
                logger.log(log_level::INFO, "#{gid} --> Syncmode for folder #{folder_name.to_s} is set to 'none', please use SFTP/RSYNC or an equivalent to sync files with the guest.")
              else
                # we currently do not support other types of mount types, but they can be added here easily if needed
                logger.log(log_level::ERROR, "#{gid} --> Unknown/Unimplemented Mounttype for folder #{folder_name.to_s}. Skipping...")
            end
          end
        end
      end
    end
  end
end