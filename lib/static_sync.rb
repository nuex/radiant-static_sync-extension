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
      'tmp/' + checksum_file
    end

    def ftp_config
      YAML::load_file('config/ftp.yml')
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

    def sync
      Net::FTP.open(ftp_config[:host], ftp_config[:user], ftp_config[:password]) do |ftp|

        ftp.chdir(ftp_config[:root]) if ftp_config[:root]

        old_checksums = {}
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

        cache = []
        to_upload.each do |file|
          dir_tree(file).each do |dir|
            unless cache.include?(dir)
              if ftp.list(dir).empty?
                puts " Making directory: #{dir}"
                begin
                  ftp.mkdir(dir)
                rescue Net::FTPPermError
                  puts " ! Directory already created"
                end
              end
              # Track remote directories so we don't have
              # to create or check if they exist again
              cache << dir
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

    # Build the checksums based on the current file snapshot
    def make_checksums
      checksums = {}
      filenames = Dir[static_path + '/**/*.*'].entries
      filenames.each do |f|
        checksums[f.gsub(static_path, '')] = Digest::MD5.hexdigest(File.read(f))
      end
      checksums
    end

    # Build arrays of what to upload and what to delete
    def file_queues(old, current)
      uploading = []
      current.each_pair do |file, sum|
        uploading << to_relative(file) if old[file] != sum
        old.delete(file)
      end
      deleting = old.keys.collect{|f| to_relative(f)}
      [uploading, deleting]
    end

    # Break the incoming file name into a tree of directories
    def dir_tree(file)
      dirs = []

      # Make the file an absolute path to make File interpret
      # it the way we want
      dir = File.dirname("/#{file}")

      until (dir == '/')
        dirs << to_relative(dir)
        dir, base = File.split(dir)
      end

      dirs.reverse
    end

    # Convert a path to a relative path (remove the leading /)
    def to_relative(path)
      path[1..-1]
    end

  end
end
