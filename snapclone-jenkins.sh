#!/bin/bash
#
# This script refreshes an ASM-based Oracle database target Database, including
# taking a protection group snapshot of the production database cbora1 and applying
# the snapshots of the ASM groups DATA and FRA to the target database cbora2
#
# THIS IS INTENDED AS AN EXAMPLE ONLY, AND SHOULD NOT BE CONFIGURED PRODUCTION
# READY.  IT IS PROVIDED "AS-IS" WITH NO WARRANTY THAT IT WILL DO ANYTHING
# EXCEPT TAKE UP SPACE ON YOUR SYSTEM (UNLESS YOU'RE USING DEDUP, IN WHICH
# CASE IT MAY NOT EVEN DO THAT!)
#
# Author:   Chris Bannayan
# Date:     15/08/2020
# Rev:      0.1
# Platform: Unix,Linux


#
# Define Glbal variables
#

SNAPDIR=$PWD/snapdir
FA1="10.226.224.112"
USER="pureuser"
TIME=`date +%Y%m%d%H%M%S`
SNAPNAME="snap-$TIME"
VOLTARGETDATA="ora2-data"
VOLTARGETFRA="ora2-fra"
PGROUP_PROD=cbora
DB_HOME=/u01/app/oracle/product/19c/dbhome_1
GRID_HOME=/u01/app/grid

#
# Funtion to stop the Oracle Grid infrastructure
#

grid_stop ()
{

export ORACLE_SID=+ASM
export ORACLE_HOME=$GRID_HOME
export PATH=$PATH:$HOME/.local/bin:$ORACLE_HOME/bin

        echo "About to unmount ASM disk groups +DATA & +FRA"
        echo "alter diskgroup DATA dismount force;" | sqlplus -s / as sysasm
        echo "alter diskgroup FRA dismount force ;" | sqlplus -s / as sysasm
}

#
# Function to stop the Oracle database
#

ora_stop ()
{

export ORACLE_SID=orcl
export ORACLE_HOME=$DB_HOME
export PATH=$PATH:$ORACLE_HOME/bin
sleep 2
echo "Shutting Down Oracle Database"
echo "shutdown immediate" | sqlplus -s / as sysdba
}

#
# Function to stop the Oracle database
#

ora_start ()
{

export ORACLE_SID=orcl
export ORACLE_HOME=$DB_HOME
export PATH=$PATH:$ORACLE_HOME/bin
sleep 2
echo "Starting Oracle Database"
echo "startup" | sqlplus -s / as sysdba
}

#
# Function to start the Grid infrastructure
#

grid_start ()
{

export ORACLE_SID=+ASM
export ORACLE_HOME=$GRID_HOME
export PATH=$PATH:$HOME/.local/bin:$ORACLE_HOME/bin

        echo "About to unmount ASM disk groups +DATA & +FRA"
        echo "alter diskgroup DATA mount;" | sqlplus -s / as sysasm
        echo "alter diskgroup FRA mount ;" | sqlplus -s / as sysasm
}

grid_stop
ora_stop

pgroup ()
{
 ssh $USER@$FA1 "purepgroup snap $PGROUP_PROD --suffix $SNAPNAME"
}

pgroup
ssh pureuser@10.226.224.112 "purevol list "|grep cbora1 > $SNAPDIR/vol-list
ssh pureuser@10.226.224.112 "purevol list --snap"|grep cbora.snap > $SNAPDIR/snapvol.list
ssh pureuser@10.226.224.112 "purepgroup list --snap cbora"|head -2 > $SNAPDIR/pgsnap.list
>$SNAPDIR/vols
>$SNAPDIR/snaps
>$SNAPDIR/final
cat $SNAPDIR/vol-list|awk '{print $1}' > $SNAPDIR/vol
for i in `cat $SNAPDIR/vol`
do
  echo $i >> $SNAPDIR/vols
  cat $SNAPDIR/snapvol.list|awk -v vol="$i" '$0 ~ vol {print $1}'|head -1
done > $SNAPDIR/snaps
paste -d " " $SNAPDIR/snaps $SNAPDIR/target > $SNAPDIR/final
sed 's/ *$//' $SNAPDIR/final > $SNAPDIR/final1
input="$SNAPDIR/final"

      #echo "refreshing from latest $VOLPRIM snapshot `cat $SNAPDIR/cb1.log|awk '{print $1}'`

      while IFS=" " read -r f1 f2
         do ssh $USER@$FA1 purevol copy --overwrite "$f1" "$f2" </dev/null
      done < "$input"



#grid_stop
#ora_stop
grid_start
ora_start