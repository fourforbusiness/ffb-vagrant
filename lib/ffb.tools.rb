# -*- mode: ruby -*-
# vi: set ft=ruby :

# --------------------------------
# ---------custom modules---------
# --------------------------------

module Tools
  LOG_PREFIX = 'Ffb-Vagrant: '
  module Tools::Enum
    module Enum::PROVISIONER
      ANSIBLE = "ansible"
      PUPPET  = "puppet"
      DOCKER  = "docker"
      SHELL   = "shell"
      CHEF    = "chef"
    end

    module Enum::PROVIDER
      VIRTUALBOX = "virtualbox"
      VMWARE     = "vmware"
      AWS        = "aws"
    end

    module Enum::FILEMOUNT_TYPE
      NONE  = "none"
      NFS   = "nfs"
      SMB   = "smb"
      RSYNC = "rsync"
    end
  end

  module Logger
    module Logger::LOG_LEVEL
      DEBUG = 0
      INFO = 1
      WARNING = 2
      ERROR = 4
    end

    module Logger::LOG_COLOR
      DEBUG   = ""
      INFO    = "\e[32m"
      WARNING = "\e[35m"
      ERROR   = "\e[31m"
      RESET   = "\e[0m"
    end

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

  module Data
    include Tools::Logger
    def self.getyaml(path, exit_on_fail = false, silent = true, description = nil, symbolize_data = true)
      path = File.expand_path(path)
      if File.file?(path)
        data = YAML.load_file(path)
        if description
          Logger.log(Logger::LOG_LEVEL::INFO, "Loaded file #{description} from #{path}.")
        end
        return symbolize_data ? symbolize(data) : data
      else
        message = "Could not load file from #{path}"
        if exit_on_fail
          Logger.log(Logger::LOG_LEVEL::ERROR, "#{message}, Exiting...")
          exit 1
        else
          unless silent
            Logger.log(Logger::LOG_LEVEL::WARNING, message)
          end
        end
      end
    end

    def self.rec_deep_merge(source, dest, depth="")
      debug = false
      depth = "  #{depth}"

      debug == true ? puts("#{depth}------start------"):false
      debug == true ? puts("#{depth}source :#{source.class.name}"):false
      debug == true ? puts("#{depth}dest   :#{dest.class.name}"):false
      debug == true ? puts("#{depth}-----------------"):false

      src_dup = source.dup
      dst_dup = dest.dup
      return_value = {}
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

  module System
    module System::OS_TYPE
      WIN  = "win"
      MAC  = "mac"
      LNX  = "linux"
    end
    def self.detect
      os_detected = (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil ? "win" : "unknown"
      os_detected = (/darwin/ =~ RUBY_PLATFORM) != nil ? "mac" : os_detected
      # for non ruby devs: ruby always returns the result of the last processed line of code
      (!os_detected.eql? "win" and !os_detected.eql? "mac") ? "linux" : os_detected
    end
  end

  module User
    include Tools::Logger
    def self.setup(local_conf_dir, local_conf_file, vagrant_environment)
      is_build_env = vagrant_environment == 'build'
      use_hostmanager = false || is_build_env
      local_conf_dir = File.expand_path("#{local_conf_dir}")
      local_conf_path =  local_conf_dir + "/" + local_conf_file
      unless File.file?(local_conf_path)
        Logger.log(LOG_LEVEL::WARNING,'The local config file for Vagrant could not be found, create it?')
        if is_build_env || Tools::Feedback::yesno
          FileUtils::mkdir_p local_conf_dir
          Logger.log(LOG_LEVEL::WARNING, 'Do you want to let Vagrant manage the Host-Entries on the current host?')
          use_hostmanager = is_build_env ? true : Tools::Feedback::yesno
          begin
            File.write(local_conf_path, "--- \nvagrant:\n  hostmanager:\n    manage_host: #{use_hostmanager}\n")
            Logger.log(LOG_LEVEL::INFO, "Successfully created #{local_conf_path}")
          rescue
            Logger.log(LOG_LEVEL::ERROR, "Could not write file at #{local_conf_path}. Exiting...")
            exit 1
          end
        end
      end
    end
  end
end