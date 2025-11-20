all:
	odin build . -out:opaint -o:speed

clean:
	rm -f ./opaint

run:
	./opaint
