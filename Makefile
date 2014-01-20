SRC=$(wildcard src/*.d)
all: $(SRC)
	echo $(SRC)
	dmd -Isrc $(SRC) -ofdcstats -L-lcurl -de -w
	./dcstats

clean:
	rm dcstas
