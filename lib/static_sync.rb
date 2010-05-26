require 'digest/md5'
require 'net/ftp'

module StaticSync
  class << self

    def static_path
      File.join('tmp', 'static')
    end

    def render_pages
      puts " Rendering pages"
      Page.all.each do |p|

        # FIXME cannot render 404 page
        next if p.id == 2

        if p.published? && (body = p.render)
          dir, filename = p.url, "index.html"
          dir, filename = p.parent.url, p.slug if p.slug =~ /\.[^.]+$/i # File with extension (e.g. styles.css)
          FileUtils.mkdir_p(File.join(static_path, dir))
          File.open(File.join(static_path, dir, filename), 'w') { |io| io.print(body) }
        else
          puts " ! Not rendering #{p.id} - #{p.status.name} - #{p.url}"
        end
      end
    end

    def clone_from_public
      puts " Copying in the public directory"
      FileUtils.cp_r('public/.', static_path)
    end

    def make_checksums
      checksums = {}
      Dir[static_path + '/**/*.*'].entries.each do |f|
        checksums[f.gsub(/tmp\/static\//, '')] = Digest::MD5.hexdigest(File.read(f))
      end
      return checksums
    end

    def build_command_list(old_checksums, new_checksums)
      commands = []
      new_checksums.each_key do |k|
        unless old_checksums.has_key?(k) and (old_checksums[k] == new_checksums[k])
          commands << { :put => k }
        end
        old_checksums.delete(k)
      end
      old_checksums.each_key do |k|
        commands << { :delete => k }
      end
      return commands
    end

    def ftp_config
      YAML::load_file('config/ftp.yml')
    end

    def sync
      Net::FTP.open(ftp_config[:host], ftp_config[:user], ftp_config[:password]) do |ftp|
        known_dirs = []

        ftp.chdir(ftp_config[:root])

        # Get current state of remote site by downloading
        # the previous yaml of checksums
        checksum_path = 'tmp/checksums.yml'
        unless ftp.list('checksums.yml').empty?
          ftp.get('checksums.yml', checksum_path)
          old_checksums = YAML::load_file(checksum_path)
        else
          old_checksums = {}
        end
        new_checksums = make_checksums
        command_list = build_command_list(old_checksums, new_checksums)

        unless command_list.empty?
          command_list.each do |instruction|
            instruction.each do |command, file|
              if command == :put
                # Make a tree of directories that may or may not
                # need to be created
                dir_parts = file.split('/')
                dir_parts = dir_parts[0, (dir_parts.length - 1)]
                dirs = []
                dir_parts.each do |dir_part|
                  path = dirs.join('/')
                  if dir_part != dir_parts.first
                    path << '/'
                  end
                  path << dir_part
                  dirs << path
                end

                dirs.each do |dir|
                  if !known_dirs.include?(dir)
                    if ftp.list(dir).empty?
                      puts " Making directory: #{dir}"
                      ftp.mkdir(dir)

                      # Track created directories so we don't
                      # have to create them again
                      known_dirs << dir
                    end
                  end
                end
                puts " Uploading: #{file}"
                local_file = File.join(static_path, file)
                ftp.put(local_file, file)
              else
                puts " Deleting: #{file}"
                ftp.delete(file)
              end
            end
          end

          # Upload the new checksums
          File.open(checksum_path, 'w') do |f|
            f.write(new_checksums.to_yaml)
          end
          puts " Uploading new checksums."
          ftp.put(checksum_path, 'checksums.yml')

          puts " All done."
        else
          puts " ! Files already synced"
        end
      end
    end
  end
end
