require 'digest/md5'
require 'net/ftp'

module StaticSync
  class << self

    def static_path
      'tmp/static'
    end

    def checksum_file
      'checksums.yml'
    end

    def checksum_path
      'tmp' + checksum_file
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


    def ftp_config
      YAML::load_file('config/ftp.yml')
    end

    def sync
      Net::FTP.open(ftp_config[:host], ftp_config[:user], ftp_config[:password]) do |ftp|

        ftp.chdir(ftp_config[:root]) if ftp_config[:root]

        old_checksums = []
        unless ftp.list(checksum_file).empty?
          # Get current state of remote site by downloading
          # the previous yaml of checksums
          ftp.get(checksum_file, checksum_path)
          old_checksums = YAML::load_file(checksum_path)
        end

        new_checksums = make_checksums
        to_upload, to_delete = file_queues(old_checksums, new_checksums)

        if to_upload.empty? && to_delete.empty?
          puts " ! Files already synced"
          return
        end

        created_directories = []
        to_upload.each do |file|
          directory_tree(file).each do |dir|
            unless created_directories.include?(dir)
              if ftp.list(dir).empty?
                puts " Making directory: #{dir}"
                ftp.mkdir(dir)

                # Track created directories so we don't
                # have to create them again
                created_directories << dir
              end
            end
          end
          puts " Uploading: #{file}"
          local_file = File.join(static_path, file)
          ftp.put(local_file, file)
        end

        to_delete.each do |file|
          puts " Deleting: #{file}"
          ftp.delete(file)
        end

        # Upload the new checksums
        File.open(checksum_path, 'w') do |f|
          f.write(new_checksums.to_yaml)
        end
        puts " Uploading new checksums."
        ftp.put(checksum_path, checksum_file)

        puts " All done."
      end
    end

    private

    def make_checksums
      checksums = {}
      filenames = Dir[static_path + '/**/*.*'].entries
      filenames.each do |f|
        checksums[f.gsub(static_path, '')] = Digest::MD5.hexdigest(File.read(f))
      end
      checksums
    end

    def file_queues(old, current)
      uploading = []
      current.each_pair do |file, sum|
        uploading << file if old[file] != sum
        old.delete(file)
      end
      deleting = old.keys
      [uploading, deleting]
    end

    # Make a tree of directories that may or may not
    # need to be created
    def directory_tree(file)
      dir_parts = file.split('/')
      dir_parts = dir_parts[0, (dir_parts.length - 1)]
      dirs = []
      dir_parts.each do |dir_part|
        path = dirs.join('/')
        path << '/' if dir_part != dir_parts.first
        path << dir_part
        dirs << path
      end
      dirs
    end
  end
end
