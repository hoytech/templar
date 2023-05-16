all:
	perl ../templar.pl tmpls/ tmpl mytmpls.h
	g++ -std=c++17 ex.cpp -o ex

clean:
	rm -f mytmpls.h ex
