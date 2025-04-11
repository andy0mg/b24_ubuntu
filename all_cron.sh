#!/bin/sh
#
# use
# bash <(curl -sL https://raw.githubusercontent.com/andy0mg/b24_ubuntu/refs/heads/main/all_cron.sh)
echo "== Пользовательские crontab =="
for user in $(cut -f1 -d: /etc/passwd); do
  echo "--- $user ---"
  crontab -u $user -l 2>/dev/null
done

echo "== /etc/crontab =="
cat /etc/crontab

echo "== /etc/cron.d/ =="
cat /etc/cron.d/* 2>/dev/null

echo "== Ежедневные/еженедельные задания =="
ls -l /etc/cron.daily /etc/cron.weekly /etc/cron.hourly /etc/cron.monthly 2>/dev/null
