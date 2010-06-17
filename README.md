# Static Sync

## OVERVIEW

This extension is for a scenario where you want to use Radiant CMS but the web host does not have Ruby and only allows FTP access.

StaticSync creates a YAML file of MD5 Checksums of all of your files and uploads it along with all of your other files to the configured FTP account. The next time you sync, StaticSync compares checksums of the current filesystem with the remote cache of checksums and uploads, creates directories, or removes files accordingly, so only changed files are affected.

I created this because I didn't need the overhead of Git or something else to track versioning of the files to be uploaded. I was using the Radiant snapshot extension, git, rsync, and git-ftp.py to take care of this and now I can do it all with just one rake task.

## INSTALL

    git submodule add git://github.com/promptsite/radiant-static_sync-extension.git vendor/extensions/static_sync

## USAGE

Create a ftp.yml file in your 'config' directory similar to the following:

    ---
    :host: remotesite.com
    :user: myuser
    :password: sup3rs3kr3t!
    :root: /public_html

Run 'rake static:build' to build the static site and 'rake static:sync' to sync the static site with the remote FTP account. A 'rake static:build_and_sync' task is available to take care of both in one go.

## THANKS

The Radiant page to static file code is from jaknowlden's electrostatic extension: http://github.com/thumblemonks/radiant-electrocstatic-extension/.

