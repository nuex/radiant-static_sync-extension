# OVERVIEW

This extension is for a scenario where you want to use Radiant CMS but the web host does not have Ruby and only allows FTP access.

# INSTALL

    git submodule add git://github.com/promptsite/radiant-static_sync-extension.git vendor/extensions/static_sync

# USAGE

Create a ftp.yml file in your 'config' directory similar to the following:

    ---
    :host: remotesite.com
    :user: myuser
    :password: sup3rs3kr3t!
    :root: /public_html

Run 'rake static:build' to build the static site and 'rake static:sync' to sync the static site with the remote FTP account. A 'rake static:build_and_sync' task is available to take care of both in one go.

# THANKS

The Radiant page to static file code is from jaknowlden's electrostatic extension: http://github.com/thumblemonks/radiant-electrocstatic-extension/.

