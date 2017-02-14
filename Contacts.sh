#!/bin/bash

cd "$HOME/Library/Application Support/AddressBook"

find . -name "AddressBook-v22.abcddb" | while read file;
do
  echo \
  "
  CREATE TEMPORARY TABLE ZSWIFT AS
  SELECT
    strftime('%m', date(ZBIRTHDAYYEARLESS, 'unixepoch', 'localtime')) AS Month,
    strftime('%d', date(ZBIRTHDAYYEARLESS, 'unixepoch', 'localtime')) AS Day,
    ZBIRTHDAYYEAR AS BirthdayYear,
    CASE WHEN
      strftime('%m%d', date(ZBIRTHDAYYEARLESS, 'unixepoch', 'localtime')) < strftime('%m%d')
      THEN strftime((strftime('%Y') + 1) || '-%m-%d', date(ZBIRTHDAYYEARLESS, 'unixepoch', 'localtime'))
      ELSE strftime(strftime('%Y') || '-%m-%d', date(ZBIRTHDAYYEARLESS, 'unixepoch', 'localtime'))
      END AS NextOccur,
    CASE WHEN
      strftime('%m%d', date(ZBIRTHDAYYEARLESS, 'unixepoch', 'localtime')) < strftime('%m%d')
    THEN 1
    ELSE 0
    END AS NewYear,
    (COALESCE(ZFIRSTNAME, '') || ' ' || COALESCE(ZMIDDLENAME, '') || ' ' || COALESCE(ZLASTNAME, '')) AS Fullname,
    'Birthday' AS EventType,
    (
      SELECT
        GROUP_CONCAT(ZFULLNUMBER, ', ')
      FROM ZABCDPHONENUMBER
      WHERE
        ZOWNER = ZABCDRECORD.Z_PK
      ORDER BY ZISPRIMARY DESC, ZORDERINGINDEX ASC
    ) AS Phone
  FROM ZABCDRECORD 
  WHERE ZBIRTHDAYYEARLESS > 0
  ORDER BY ZBIRTHDAYYEARLESS ASC;
  
  INSERT INTO ZSWIFT
  SELECT
    strftime('%m', date(ZDATEYEARLESS, 'unixepoch', 'localtime')) AS Month,
    strftime('%d', date(ZDATEYEARLESS, 'unixepoch', 'localtime')) AS Day,
    ZDATEYEAR AS BirthdayYear,
    CASE WHEN
      strftime('%m%d', date(ZDATEYEARLESS, 'unixepoch', 'localtime')) < strftime('%m%d')
      THEN strftime((strftime('%Y') + 1) || '-%m-%d', date(ZDATEYEARLESS, 'unixepoch', 'localtime'))
      ELSE strftime(strftime('%Y') || '-%m-%d', date(ZDATEYEARLESS, 'unixepoch', 'localtime'))
      END AS NextOccur,
    CASE WHEN
      strftime('%m%d', date(ZDATEYEARLESS, 'unixepoch', 'localtime')) < strftime('%m%d')
    THEN 1
    ELSE 0
    END AS NewYear,
    (COALESCE(ZFIRSTNAME, '') || ' ' || COALESCE(ZMIDDLENAME, '') || ' ' || COALESCE(ZLASTNAME, '')) AS Fullname,
    ZLABEL AS EventType,
    (
      SELECT
        GROUP_CONCAT(ZFULLNUMBER, ', ')
      FROM ZABCDPHONENUMBER
      WHERE
        ZOWNER = ZABCDCONTACTDATE.ZOWNER
      ORDER BY ZISPRIMARY DESC, ZORDERINGINDEX ASC
    ) AS Phone
  FROM ZABCDCONTACTDATE
  JOIN ZABCDRECORD ON ZABCDCONTACTDATE.ZOWNER = ZABCDRECORD.Z_PK;
  
  SELECT 
    Day || '.' || Month || 
    CASE WHEN BirthdayYear > 1604
      THEN '.' || BirthdayYear
      ELSE '.XXXX'
    END,
    JULIANDAY(NextOccur) - JULIANDAY(),
    *,
    strftime('%Y') - BirthdayYear
  FROM ZSWIFT
  ORDER BY NextOccur;
  
  " | sqlite3 $file | while read line;
  do
    EVENTDATE=`echo $line | cut -f1 -d"|"`
    DIFF=`echo $line | cut -f2 -d "|"`
    DIFF_CEIL=`python -c "from math import ceil; print int(ceil($DIFF))"`
    EVENTTYPE=`echo $line | cut -f9 -d "|" | sed -e "s/^\_\$\!\<//" -e "s/\>\!\$\_$//"`
    
    FULLNAME=`echo $line | cut -f8 -d "|"`
    PHONE=`echo $line | cut -f10 -d "|"`
    AGE=`echo $line | cut -f11 -d "|"`

    echo -n "in $DIFF_CEIL days | ${EVENTTYPE} | $EVENTDATE "
    
    if [ `echo $line | cut -f7 -d "|"` -gt 0 ]; then
      let "AGE+=1"
    fi
    
    if [ "$EVENTTYPE" == "Birthday" ]; then
      if [ $AGE -gt 0 ]; then
        echo -n "($AGE Yo) "
      fi
    else
      if [ $AGE -gt 0 ]; then
        echo -n "($AGE Yr)"
      fi
    fi
    
    echo -n "| $FULLNAME | $PHONE"
    
    echo ""
  done
done
