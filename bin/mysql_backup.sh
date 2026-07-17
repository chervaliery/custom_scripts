#!/bin/sh

CONFIG_FILE="/etc/custom_scripts/mysql_backup.env"

if [ -f "$CONFIG_FILE" ]; then
    . "$CONFIG_FILE"
fi

: "${DB_USER:=root}"
: "${DB_PASS:=""}"

DST="/opt/mysql_export"
IGNREG='^information_schema|cond_instances$'
KEEPDAYS=15

DATE=$(date  +%Y-%m-%d)

cd /var/lib/mysql

if [ ! -e $DST ]; then
        mkdir $DST
fi

find ${DST} -type f -mtime +${KEEPDAYS} -exec rm -f {} \;
rmdir $DST/* 2>/dev/null

mkdir -p ${DST}/${DATE}
for db in $(echo 'show databases;' | mysql -s -u ${DB_USER} -p${DB_PASS} | egrep -v ${IGNREG}) ; do
        echo -n "Backing up ${db}... "
        mysqldump --single-transaction  --opt -u ${DB_USER} -p${DB_PASS} $db | gzip -c > ${DST}/${DATE}/${db}.txt.gz
        echo "Done."
done

chown -R root:deluge $DST
chmod -R 770 $DST

exit 0
