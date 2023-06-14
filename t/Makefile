test: ex
	perl html.pl
	perl replacement.pl
	./ex |perl check-ex.pl

ex: ../templar.pl ../Parser.pm ex.cpp $(shell find tmpls/ -type f -name '*.tmpl')
	perl ../templar.pl tmpls/ tmpl mytmpls.h
	g++ -Wall -std=c++17 ex.cpp -o ex

clean:
	rm -f mytmpls.h ex
