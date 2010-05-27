namespace :static do
  desc "Generate rendered Pages, store in ./tmp directory, copy in public assets"
  task :build => :environment do
    StaticSync.render_pages
    StaticSync.clone_from_public
  end

  desc "Sync with remote ftp site"
  task :sync => :environment do
    StaticSync.sync
  end

  desc "Build the static site and sync it with a remote ftp account"
  task :build_and_sync => :environment do
    Rake::Task['build'].invoke
    Rake::Task['sync'].invoke
  end

  desc "Clean up any static_sync artifacts"
  task :clean => :environment do
    sh "rm -fr tmp/static"
  end

end
