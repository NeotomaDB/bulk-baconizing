#!/bin/bash

rinstall=0

while getopts "i" OPTION
do
	case $OPTION in
		i)
			echo Running installLib with the option to install packages.
			rinstall=1
			;;
	esac
done

rpath=$(Rscript -e "cat(.libPaths())")

library=$(cat $(find . -type f \( -name \*.R -o -name \*.Rmd \)) | sed -n 's/^library[(]\(.*\)[)]/\1/p' | tr "," "\n" | tr -d "[\"\\']" | sed "s/\(quietly\|verbose\)\s*=\s*\(\(TRUE\)\|\(FALSE\)\)/ /g")
library+=$(cat $(find . -type f \( -name \*.R -o -name \*.Rmd \)) | sed -n 's/^require[(]\(.*\)[)]/ \1/p' | tr "," "\n" | tr -d "[\"\\']" | sed "s/\(quietly\|verbose\)\s*=\s*\(\(TRUE\)\|\(FALSE\)\)/ /g")
library+=$(cat $(find . -type f \( -name \*.R -o -name \*.Rmd \)) | sed -n 's/^.*\@import\(From\)\?\s\([a-zA-Z]*\)\s.*/ \2/p')
library+=$(cat $(find . -type f \( -name \*.R -o -name \*.Rmd \)) | perl -e 's/(.*?)([[:alnum:]]+)(:{2,3})(.*?)|./ \2/g' | sed '/^\s*$/d')

installs=$(tr ' ' '\n' <<< "${library[@]}" | sort -u | tr '\n' ' ')

for onePkg in $installs; do
	install=0

	for paths in $rpath; do
		test -d "$paths/$onePkg" && install=1
	done

	test $install -eq 0 && printf "  The package %s hasn\'t been installed.\n" $onePkg

	test $install -eq 0 && test $rinstall -eq 1 && printf "  * Will now install the package.\n" && Rscript -e "install.packages (\"$onePkg\", repos=\"http://cran.r-project.org/\")"
done
