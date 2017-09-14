#!/bin/bash

# there are several things that go on the /media/RACHEL
# partition, which would have just been partitioned and
# formatted as part of the install -- so we copy them
# over on first boot here.

rootDir=/root/rachel-scripts/files
rachelDir=/media/RACHEL

# copy the minimal RACHEL contentshell
echo $(date) - Copy the minimal RACHEL contentshell
if [[ ! -d $rachelDir/rachel ]]; then
    rsync -ahPl $rootDir/rachel $rachelDir
    bash $rachelDir/rachel/admin/post-update-script.sh
fi

# copy the initial .kalite (includes password)
echo $(date) - Copy the initial .kalite \(includes password\)
if [[ ! -d $rachelDir/.kalite ]]; then
    rsync -ahPl $rootDir/.kalite $rachelDir
    
fi

# copy the moodle directory, create data dir
echo $(date) - Copy the moodle directory, create data dir
if [[ ! -d $rachelDir/moodle ]]; then
    rsync -ahPl $rootDir/moodle $rachelDir
    ln -s $rachelDir/moodle $rachelDir/rachel
    mkdir $rachelDir/moodle-data
    chmod 777 $rachelDir/moodle-data
fi

# copy the mysql data directory (contains moodle)
echo $(date) - Copy the mysql data directory \(contains moodle\)
if [[ ! -d $rachelDir/mysql ]]; then
    rsync -ahPl $rootDir/mysql $rachelDir
    groupadd mysql
    chown -R mysql:mysql $rachelDir/mysql
    find $rachelDir/mysql -type d -print0 | xargs -0 chmod 0700
    find $rachelDir/mysql -type f -print0 | xargs -0 chmod 0660
    service mysql start
fi

# legacy support
echo $(date) - Add legacy support for KA Lite content folder
ln -s /media/RACHEL/.kalite/content /media/RACHEL/kacontent

# AUTO INSTALL
# if you modify the files in the install USB root directory,
# you can control the automatic module installation. See:
#   - rachel-autoinstall.modules - list of modules to install
#   - rachel-autoinstall.server  - server to install from
#   - rachel-autoinstall.sh      - any special post-install action
echo $(date) - Auto Install Modules
if [[ -f $rootDir/rachel-autoinstall.modules && -f $rootDir/rachel-autoinstall.server ]]; then
    # clear the tasks table, just in case sam doesn't :)
    sqlite3 $rachelDir/rachel/admin/admin.sqlite "DELETE FROM tasks"
    # add autoinstall tasks
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