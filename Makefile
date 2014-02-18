SRC=$(wildcard src/*.d)
all: $(SRC)
	echo $(SRC)
	dmd -Isrc $(SRC) -ofdcstats -L-lcurl -de -w -unittest -gc -debug
	./dcstats

clean:
	rm dcstas

#-I../Tango-D2 ../Tango-D2/libtango-dmd.a
