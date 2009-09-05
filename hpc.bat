mkdir .hpc
ghc --make -isrc -i. src\Main.hs -w -fhpc -odir .hpc -hidir .hpc -threaded -o .hpc\hlint-test
del hlint-test.tix
.hpc\hlint-test --help
.hpc\hlint-test --test
hpc.exe markup hlint-test.tix --destdir=.hpc
hpc.exe report hlint-test.tix
del hlint-test.tix
start .hpc\hpc_index_fun.html
