# -*- mode: ruby -*-
# vi: set ft=ruby :

# --------------------------------
# ---------custom modules---------
# --------------------------------
# a collection of tools that are used in the framework
module Tools

  # the global log-prefix to identify log output from the vagrant framework
  LOG_PREFIX = 'Ffb-Vagrant: '

  # a collection of enums used in the application
  module Tools::Enum

    # this list contains the known and supported provisioners
    # the commented provisioners are not yet implemented
    module Enum::PROVISIONER
      ANSIBLE = "ansible"
      # SHELL   = "shell"
      # PUPPET  = "puppet"
      # DOCKER  = "docker"
      # CHEF    = "chef"
    end

    # this list contains the known and supported virtualization tools
    # the commented tools are not yet implemented
    module Enum::PROVIDER
      VIRTUALBOX = "virtualbox"
      # VMWARE     = "vmware"
      # AWS        = "aws"
    end

    # a list of possible ways to link files into the vm
    module Enum::FILEMOUNT_TYPE
      NONE  = "none"
      NFS   = "nfs"
      SMB   = "smb"
      RSYNC = "rsync"
    end
  end

  # a simple logging engine
  module Logger

    # a collection of log levels to identify the log level of the output
    module Logger::LOG_LEVEL
      DEBUG = 0
      INFO = 1
      WARNING = 2
      ERROR = 4
    end

    # different log levels are displayed in different colors
    module Logger::LOG_COLOR
      DEBUG   = ""
      INFO    = "\e[32m"
      WARNING = "\e[35m"
      ERROR   = "\e[31m"
      RESET   = "\e[0m"
    end

    # log a specific message on the console with the correct level and color
    def self.log(log_level, text)
      output_message = nil
      case log_level
        when Logger::LOG_LEVEL::DEBUG
          output_message = LOG_COLOR::DEBUG + LOG_PREFIX + Logger::LOG_COLOR::RESET + text + Logger::LOG_COLOR::RESET
        when Logger::LOG_LEVEL::INFO
          output_message = LOG_COLOR::INFO + LOG_PREFIX + Logger::LOG_COLOR::INFO + text + Logger::LOG_COLOR::RESET
        when Logger::LOG_LEVEL::WARNING
          output_message = LOG_COLOR::WARNING + LOG_PREFIX + Logger::LOG_COLOR::WARNING + text + Logger::LOG_COLOR::RESET
        when Logger::LOG_LEVEL::ERROR
          output_message = LOG_COLOR::ERROR + LOG_PREFIX + Logger::LOG_COLOR::ERROR + text + Logger::LOG_COLOR::RESET
        else
          puts "Error in Logger... Exiting..."
          exit 1
      end
      puts output_message
    end

  end

  # a simple module to get user-feedback
  module Feedback
    def self.yesno
      puts "(y/n)"
      case $stdin.gets.chomp
      when "y" then true
      when "n" then false
      else
        puts "Invalid character."
        yesno
      end
    end
  end

  # a collection of functions that help working with data
  module Data
    # load the logger
    include Tools::Logger
    # load yaml from a file
    # path(string), the absolute path from where to load the file
    # exit_on_fail(bool), default: false, if loading the file is mandatory for the execution of the program, it can be stopped on an error
    # silent(bool), default: true, if the file cannot be loaded, the program can display a warning
    # description(string), default: nil, a brief description of the files purpose
    # symbolize_data(bool), default: true, if the result should be a hash with symbolized keys
    def self.getyaml(path, exit_on_fail = false, silent = true, description = nil, symbolize_data = true)
      # get the absolute path of the file
      path = File.expand_path(path)
      begin
        # load the file via ruby
        data = YAML.load_file(path)
        if description
          # display a log message on the console
          Logger.log(Logger::LOG_LEVEL::INFO, "Loaded file #{description} from #{path}.")
        end
        # return the loaded data
        return symbolize_data ? symbolize(data) : data
      rescue
        # message if the file could not be loaded
        message = "Could not load file from #{path}"
        # exit with error message
        if exit_on_fail
          Logger.log(Logger::LOG_LEVEL::ERROR, "#{message}, Exiting...")
          exit 1
        end
        # continue with error message
        unless silent
          Logger.log(Logger::LOG_LEVEL::WARNING, message)
        end
      end
    end

    # merges 2 collections recursively and creates a sum of both
    # the input can be two arrays or two hashes or a mix
    # to enable debug output, just set debug to true
    def self.rec_deep_merge(source, dest, depth="")
      debug = false
      depth = "  #{depth}"

      debug == true ? puts("#{depth}------start------"):false
      debug == true ? puts("#{depth}source :#{source.class.name}"):false
      debug == true ? puts("#{depth}dest   :#{dest.class.name}"):false
      debug == true ? puts("#{depth}-----------------"):false

      # we crate full copys of the source and the destination to prevent changing the original objects
      src_dup = source.dup
      dst_dup = dest.dup

      # we always return a hash object
      return_value = {}

      # check if both objects are arrays
      if src_dup.is_a?(Array) and dst_dup.is_a?(Array)

        debug == true ? puts("#{depth}src_dup and dst_dup are arrays"):false
        debug == true ? puts("#{depth}-----------------"):false

        return_value = []
        src_dup.each_with_index do |value, index|

          debug == true ? puts("#{depth}#{index}:#{value}"):false
          debug == true ? puts("#{depth}-----------------"):false

          if value.is_a?(Hash) or value.is_a?(Array)
            return_value.push(rec_deep_merge(value, dst_dup[index]))
          else
            return_value.push(value)
          end
        end
      # if both objects are hashes
      elsif src_dup.is_a?(Hash) and dst_dup.is_a?(Hash)
        # copy stuff into dst that doesnt exist there but in source
        src_dup.each do |src_k, src_v|
          unless dst_dup.has_key?(src_k)
            dst_dup[src_k] = src_v
          end
        end
        # do the merge
        dst_dup.each do |dst_k, dst_v|

          debug == true ? puts("#{depth}src_k: #{dst_k}"):false
          debug == true ? puts("#{depth}src_v: #{dst_v}"):false
          debug == true ? puts("#{depth}-----------------"):false

          if dst_k.is_a?(Array)

            debug == true ? puts("#{depth}K = ARRAY"):false
            debug == true ? puts("#{depth}-----------------"):false

            return_value = dst_k
          elsif dst_k.is_a?(Hash)

            debug == true ? puts("#{depth}K = HASH"):false
            debug == true ? puts("#{depth}-----------------dst_dup"):false

            return_value = rec_deep_merge(src_k, dst_dup[dst_k], depth)
          elsif dst_v.is_a?(Hash) and dst_dup.key?(dst_k) and dst_dup[dst_k].is_a?(Hash)

            debug == true ? puts("#{depth}V = HASH"):false
            debug == true ? puts("#{depth}-----------------|||#{src_dup[dst_k].class.name}|||"):false

            return_value[dst_k] = rec_deep_merge(src_dup[dst_k], dst_dup[dst_k], depth)
          elsif dst_v.is_a?(Array) and dst_dup.key?(dst_k) and dst_dup[dst_k].is_a?(Array)

            debug == true ? puts("#{depth}V = ARRAY"):false
            debug == true ? puts("#{depth}-----------------"):false

            return_value[dst_k]
            return_value[dst_k] = rec_deep_merge(src_dup[dst_k], dst_dup[dst_k], depth)
          elsif dst_k.is_a?(Symbol) || dst_v.is_a?(Hash)

            debug == true ? puts("#{depth}SOURCE KEY IS SYMBOL OR HASH"):false
            debug == true ? puts("#{depth}-----------------"):false

            if dst_dup.has_key?(dst_k)

              debug == true ? puts("#{depth}SOURCE KEY IN DEST"):false
              debug == true ? puts("#{depth}-----------------RETURN SRC VAL(overwrite)"):false

              if src_dup[dst_k].is_a?(NilClass)

                debug == true ? puts("#{depth}src_dup[dst_k] IS NULL"):false
                debug == true ? puts("#{depth}-----------------"):false

                return_value[dst_k] = dst_v
              else

                debug == true ? puts("#{depth}src_dup[dst_k] IS NOT NULL"):false
                debug == true ? puts("#{depth}-----------------"):false

                return_value[dst_k] = src_dup[dst_k]
              end
            else

              debug == true ? puts("#{depth}SOURCE KEY NOT IN DEST"):false
              debug == true ? puts("#{depth}-----------------RETURN SCR VAL"):false

              return_value[dst_k] = dst_v
            end
          else

            debug == true ? puts("#{depth}K = #{src_k.class.name}"):false
            debug == true ? puts("#{depth}V = #{src_v.class.name}"):false
            debug == true ? puts("#{depth}-----------------"):false

            if dst_dup.key?(src_k)

              debug == true ? puts("#{depth}"):false
              debug == true ? puts("#{depth}-----------------"):false

              return_value[src_k] = src_dup[src_k]
            else
              debug == true ? puts("#{depth} UNKNOWN ROUTE"):false
            end
          end
        end
      elsif src_dup.is_a?(Hash) and dst_dup.is_a?(NilClass)

        return_value = src_dup
      else

        debug == true ? puts("#{depth}src_dup no hash"):false
        debug == true ? puts("#{depth}-----------------"):false

        return_value = dst_dup
      end

      debug == true ? puts("#{depth}------end------"):false
      debug == true ? puts("#{depth}return_value: #{return_value}"):false

      return_value
    end

    # this method exchanges all string-type keys of a hash with symbols
    def self.symbolize(hash)
      symbolized_hash = {}
      hash.each do |k, v|
        if v.is_a?(Hash)
          symbolized_hash[k.to_sym] = symbolize(v)
        elsif v.is_a?(Array)
          if k.is_a?(String)
            symbolizedSubArray = []
            v.each do |arrayItem|
              if arrayItem.is_a?(Hash)
                symbolizedSubArray.push(symbolize(arrayItem))
              else
                symbolizedSubArray.push(arrayItem)
              end
              symbolized_hash[k.to_sym] = symbolizedSubArray
            end
          elsif k.is_a?(Symbol)
            symbolized_hash[k] = v.inject({}){|memo,(key,val)| memo[key] = val; memo}
          end
        else
          if k.is_a?(String)
            symbolized_hash[k.to_sym] = v
          else
            symbolized_hash[k] = v
          end
        end
      end
      symbolized_hash
    end
  end

  # module for system related operations
  module System
    # the three types of operation systems
    module System::OS_TYPE
      WIN  = "win"
      MAC  = "mac"
      LNX  = "linux"
    end
    # detects the current operating system
    def self.detect
      # windows
      os_detected = (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil ? "win" : "unknown"
      # mac
      os_detected = (/darwin/ =~ RUBY_PLATFORM) != nil ? "mac" : os_detected
      # for non ruby devs: ruby always returns the result of the last processed line of code
      # linux/unix
      (!os_detected.eql? "win" and !os_detected.eql? "mac") ? "linux" : os_detected
    end
  end

  # this module contains user related actions
  module User
    include Tools::Logger
    # a simple setup routine that politely asks the user for the permissions to change
    # some things on the current host-machine
    def self.setup(local_conf_dir, local_conf_file, vagrant_environment)
      is_build_env = vagrant_environment == 'build'
      use_hostmanager = false || is_build_env
      local_conf_dir = File.expand_path("#{local_conf_dir}")
      local_conf_path =  local_conf_dir + "/" + local_conf_file
      unless File.file?(local_conf_path)
        Logger.log(LOG_LEVEL::WARNING,'The local config file for Vagrant could not be found, create it?')
        # in case the environment is 'build' we do not want to ask for permissions because
        # the build-server needs that files and configs in any case
        if is_build_env || Tools::Feedback::yesno
          # create the directory for the custom configuration files
          FileUtils::mkdir_p local_conf_dir
          # if usage of the hostmanager is wanted
          Logger.log(LOG_LEVEL::WARNING, 'Do you want to let Vagrant manage the Host-Entries on the current host?')
          use_hostmanager = is_build_env ? true : Tools::Feedback::yesno
          begin
            # create the config file and write the appropriate content into it
            File.write(local_conf_path, "--- \nvagrant:\n  hostmanager:\n    manage_host: #{use_hostmanager}\n")
            # just some log output
            Logger.log(LOG_LEVEL::INFO, "Successfully created #{local_conf_path}")
          rescue
            # if there was an error, we stop program execution
            Logger.log(LOG_LEVEL::ERROR, "Could not write file at #{local_conf_path}. Exiting...")
            exit 1
          end
        end
      end
    end
  end
end