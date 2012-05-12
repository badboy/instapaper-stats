# Instapaper Stats

This is a small script to backup your [Instapaper](http://instapaper.com/) data and generate some [fancy graph stuff](http://www.highcharts.com/).

I wrote about it [here](http://fnordig.de/2012/05/08/my-instapaper-stats/).

## What is needed?

Just two small gems and an [Instapaper](http://instapaper.com/) account.

    gem install mechanize mustache

## Usage

    Usage: instapaper-stats.rb [method]
    fetch [credentials file]  - Fetch new data and save to 'backup/'.
    info [csv file]           - Show info from csv file.
    search [word]             - Search article by word or url,
                                word can be a regexp.
    csv [dir]                 - Print out latest backup info in CSV format.
    csv_full [dir]            - Print out full backup info in CSV format.
    graph [csv file]          - Write stats data from csv file to 'html/app.js'.


## Daily backup

I use this script as a cronjob to automatically backup and graph all my saved articles.

    $ crontab -l
    1 0 * * * /home/badboy/git/instredis/run.sh >/dev/null
    5 0 * * * /home/badboy/git/instredis/graph.sh >/dev/null

where `run.sh` is:

    #!/bin/bash

    cd $(dirname $0)
    ~/.rvm/bin/ruby-1.9.3-p0 ./instapaper-stats.rb fetch credentials.txt

and `graph.sh`:

    #!/bin/bash

    cd $(dirname $0)
    ~/.rvm/bin/ruby-1.9.3-p0 ./instapaper-stats.rb csv backup >> full.csv
    ~/.rvm/bin/ruby-1.9.3-p0 ./instapaper-stats.rb graph full.csv
    cp html/app.js /var/www/sites/stats/app.js


## License

    "THE BEER-WARE LICENSE" (Revision 42):
    <badboy@archlinux.us> wrote this file. As long as you retain this notice you
    can do whatever you want with this stuff. If we meet some day, and you think
    this stuff is worth it, you can buy me a beer in return.
    Jan-Erik Rediger
