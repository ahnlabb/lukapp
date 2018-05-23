.PHONY : page clean

page: index.html

site/TableData.elm: site/generate.py site/TableData.template.elm lot.db
	python3 site/generate.py ./lot.db ./site/TableData.template.elm -o ./site/TableData.elm

index.html: site/TableData.elm
	(cd site && elm make Main.elm --output ../index.html)

lot.db:
	python3 extract.py create
	python3 extract.py ceq

clean:
	rm -f site/TableData.elm
	rm -f lot.db
