#!/bin/bash

sizes="1 10 100 1000"

vmargs="-XX:MaxPermSize=256m -Xms5G -Xmx5G"

for n in $sizes; do

	echo $n
	java $vmargs -jar hu.bme.mit.ttc.imdb.generator/target/hu.bme.mit.ttc.imdb.generator-1.0.0-SNAPSHOT.jar -instanceModelDir /home/szarnyasg/git/ttc14-eiq/ttc14-imdb/hu.bme.mit.ttc.imdb.instance/model -N $n
	java $vmargs -jar hu.bme.mit.ttc.imdb.transformation/target/hu.bme.mit.ttc.imdb.transformation-1.0.0-SNAPSHOT.jar -instanceModelPath /home/szarnyasg/git/ttc14-eiq/ttc14-imdb/hu.bme.mit.ttc.imdb.instance/model/synthetic-$n.movies

done
