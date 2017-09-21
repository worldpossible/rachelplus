#!/bin/bash

# there are several things that go on the /media/RACHEL
# partition, which would have just been partitioned and
# formatted as part of the install -- so we copy them
# over on first boot here.

rootDir=/root/rachel-scripts/files
rachelDir=/media/RACHEL

# copy the minimal RACHEL contentshell
if [[ ! -d $rachelDir/rachel ]]; then
    cp -r $rootDir/rachel $rachelDir
    bash $rachelDir/rachel/admin/post-update-script.sh
fi

# copy the initial .kalite (includs password)
if [[ ! -d $rachelDir/.kalite ]]; then
    cp -r $rootDir/.kalite $rachelDir
fi

# copy the moodle directory, create data dir
if [[ ! -d $rachelDir/moodle ]]; then
    cp -r $rootDir/moodle $rachelDir
    ln -s $rachelDir/moodle $rachelDir/rachel
    mkdir $rachelDir/moodle-data
    chmod 777 $rachelDir/moodle-data
fi

# copy the mysql data directory (contains moodle)
if [[ ! -d $rachelDir/mysql ]]; then
    cp -r $rootDir/mysql $rachelDir
    chown -R mysql:mysql $rachelDir/mysql
    find $rachelDir/mysql -type d -print0 | xargs -0 chmod 0700
    find $rachelDir/mysql -type f -print0 | xargs -0 chmod 0660
    service mysql start
fi

# legacy support
ln -s /media/RACHEL/.kalite/content /media/RACHEL/kacontent

# AUTO INSTALL
# if you modify the files in the install USB root directory,
# you can control the automatic module installation. See:
#   - rachel-autoinstall.modules - list of modules to install
#   - rachel-autoinstall.server  - server to install from
#   - rachel-autoinstall.sh      - any special post-install action
if [[ -f $rootDir/rachel-autoinstall.modules && -f $rootDir/rachel-autoinstall.server ]]; then
    ip=$(cat $rootDir/rachel-autoinstall.server)
    cp $rootDir/rachel-autoinstall.modules $rachelDir/rachel/scripts/
    php $rachelDir/rachel/installmods.php rachel-autoinstall $ip
    # we have to do this through the task system because
    # it needs to run after all the modules are installed
    # as the main use is making changes to installed modules,
    # such as censoring content for the dept. of justice
    if [[ -f $rootDir/rachel-autoinstall.sh ]]; then
        sqlite3 $rachelDir/rachel/admin/admin.sqlite \
        "INSERT INTO tasks (moddir, command) VALUES ('install script', 'bash $rootDir/rachel-autoinstall.sh')"
    # do_tasks.php is already running from the installmods.php call above
    fi
fi

# and remove ourselves from future execution
mv $0 ${0}.done