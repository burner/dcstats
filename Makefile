SRC=$(wildcard src/*.d)
all: $(SRC)
	echo $(SRC)
	dmd -Isrc $(SRC) -ofdcstats

clean:
	rm dcstas
