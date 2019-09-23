#########################
# Makefile
# Simon Goring
#########################

agegen: bulk_baconizing.Rmd
	Rscript -e 'rmarkdown::render(c("$<"))'

clean:
	rm -rf bulk_baconizing.html bulk_baconizing.md *.docx figure/ cache/

localbuild: bulk_baconizing.Rmd
	Rscript -e 'rmarkdown::render(c("$<"))' || Rscript -e 'knitr::purl(c("$<"))'
	find ./Cores -name "*.pdf" -print0 | sort -z | xargs -0 sh -c 'pdfunite "${@}" allcore_out.pdf'

