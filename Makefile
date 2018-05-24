.PHONY : page clean reactor

page: index.html

site/Specializations.elm: site/generate.py site/Specializations.template.elm lot.db
	python3 site/generate.py ./lot.db ./site/TableData.template.elm -o ./site/TableData.elm

site/TableData.elm: site/generate.py site/TableData.template.elm lot.db
	python3 site/generate.py ./lot.db ./site/TableData.template.elm -o ./site/TableData.elm

index.html: site/TableData.elm site/Specializations.elm
	(cd site && elm make Main.elm --output ../index.html)

reactor: site/Main.elm site/TableData.elm site/Specializations.elm
	(cd site && elm reactor)

lot.db:
	python3 extract.py create
	python3 extract.py ceq

clean:
	rm -f site/TableData.elm
	rm -f lot.db
